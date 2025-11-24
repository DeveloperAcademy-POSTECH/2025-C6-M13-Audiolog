//
//  AudioProcessor.swift
//  Audiolog
//
//  Created by 성현 on 11/6/25.
//

@preconcurrency import AVFoundation
import ChatGPTSwift
import FoundationModels
import ShazamKit
import SoundAnalysis
import Speech

@MainActor
@Observable
final class AudioProcessor {
    var isLanguageModelAvailable: Bool = true

    init() {}

    func configureLanguageModelSession() async {
        guard isLanguageModelAvailable else { return }

        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            isLanguageModelAvailable = true
            logger.log("[AudioProcessor] Language model is available.")
        default:
            isLanguageModelAvailable = false
            logger.log("[AudioProcessor] Language model is not available.")
            return
        }
    }

    func generateTitle(recording: Recording, isDummy: Bool = true) async {
        if isDummy {
            Task {
                try await Task.sleep(for: .seconds(3))
                recording.title = "웅성거리는 대화 소리, 포항시 포항공대제1융합관"
                recording.isTitleGenerated = true
            }
            return
        }

        guard isLanguageModelAvailable else {
            logger.log("[AudioProcessor] No Language Model Session.")
            recording.title = recording.location ?? "새로운 녹음"
            recording.isTitleGenerated = true
            logger.log("[AudioProcessor] title applied: \(recording.title)")
            return
        }

        let instruction = """
            입력을 30자 이내로 요약한 한국어 제목을 출력한다.

            출력형식:
             제목

            규칙:
             이유는 설명하지 않는다.
             제목외의 다른 메시지는 출력하지 않는다.
             특수문자를 사용하지 않는다.
            """

        let basePrompt = ""
        var prompt = basePrompt

        if let bgmArtist = recording.bgmArtist,
            let bgmTitle = recording.bgmTitle
        {
            prompt += "노래 \'\(bgmArtist)의 \(bgmTitle)\'"

        }

        if let dialog = recording.dialog, !dialog.isEmpty {
            prompt += "\"\(dialog)\""
        }

        if let tags = recording.tags, !tags.isEmpty, prompt == basePrompt {
            prompt += "\(tags.joined(separator: ", ")) 감지됨"
        }

        if let weather = recording.weather, prompt == basePrompt {
            prompt += "\(weather)"
        }

        logger.log("[AudioProcessor] Prompt: \(prompt)")

        do {
            var title = ""

            if let response = await generateTitleWithGPT(
                instruction: instruction,
                prompt: prompt
            ) {
                title = response
                logger.log(
                    "[AudioProcessor] Generated title with GPT: \(title)"
                )
            } else {
                if isLanguageModelAvailable {
                    let languageModelSession = LanguageModelSession(
                        instructions: instruction
                    )
                    let response = try await languageModelSession.respond(
                        to: prompt
                    )
                    title = response.content
                    logger.log(
                        "[AudioProcessor] Generated title with Foundation Model: \(title)"
                    )
                } else {
                    title = "새로운 녹음"
                }
            }

            title = title.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if let location = recording.location {
                recording.title = "\(title), " + location
            } else {
                recording.title = title
            }
            recording.isTitleGenerated = true
        } catch {
            logger.log("Title generation failed: \(error)")
        }
    }

    func classify(recording: Recording) async {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        do {
            let analyzer = try SNAudioFileAnalyzer(url: fileURL)
            let request = try SNClassifySoundRequest(
                classifierIdentifier: .version1
            )

            let observer = TopTagsObserver(topK: 3) {
                tags in
                logger.log(
                    "[AudioProcessor] Top tags: \(tags.joined(separator: ", "))"
                )

                recording.tags = tags
            }

            try analyzer.add(request, withObserver: observer)
            await analyzer.analyze()
        } catch {
            logger.log("[AudioProcessor] Sound classification failed: \(error)")
        }
    }

    func transcribe(recording: Recording) async {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        logger.log("[AudioProcessor] Start transcription: \(fileName)")

        guard
            let recognizer = SFSpeechRecognizer(
                locale: Locale(identifier: "ko-KR")
            ),
            recognizer.isAvailable
        else {
            logger.log("[AudioProcessor] Speech recognizer is not available.")
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        do {
            let text: String = try await withCheckedThrowingContinuation {
                continuation in
                var didResume = false

                recognizer.recognitionTask(with: request) { result, error in
                    if didResume { return }

                    if let error {
                        didResume = true
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let result else { return }

                    if result.isFinal {
                        didResume = true
                        continuation.resume(
                            returning: result.bestTranscription.formattedString
                        )
                    }
                }
            }

            recording.dialog = text
            logger.log("[AudioProcessor] Transcription result: \(text)")
        } catch {
            logger.log(
                "[AudioProcessor] Transcription failed: \(error.localizedDescription)"
            )
        }
    }

    func shazam(recording: Recording) async {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        guard let m4aURL = await exportToM4A(fileURL) else { return }

        if let item = try? await identifyMusic(from: m4aURL) {
            await MainActor.run {
                recording.bgmTitle =
                    item.title ?? recording.bgmTitle
                recording.bgmArtist =
                    item.artist ?? recording.bgmArtist
            }
            logger.log(
                "[AudioProcessor] (4.5) ShazamKit 매칭: \(item.title ?? "?") - \(item.artist ?? "?")"
            )
        } else {
            logger.log("[AudioProcessor] (4.5) ShazamKit 매칭 결과 없음")
        }
    }

    private func exportToM4A(_ url: URL) async -> URL? {
        let asset = AVURLAsset(url: url)

        guard
            let export = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
            )
        else { return nil }

        let m4aURL = url.deletingPathExtension().appendingPathExtension("m4a")
        export.outputURL = m4aURL
        export.outputFileType = .m4a

        guard let duration = try? await asset.load(.duration) else {
            return nil
        }
        export.timeRange = CMTimeRange(start: .zero, duration: duration)

        try? await export.export(to: m4aURL, as: .m4a)

        return m4aURL
    }

    private func identifyMusic(from url: URL) async throws
        -> SHMatchedMediaItem?
    {
        let session = SHSession()
        let maxDuration = TimeInterval(11)

        logger.log("[Shazam] identifyMusic 시작 - url: \(url.absoluteString)")
        logger.log("[Shazam] catalog.maxQueryDuration = \(maxDuration)s")

        guard let signature = makeSignature(from: url, maxDuration: maxDuration)
        else {
            logger.log("[Shazam] signature 생성 실패 (nil)")
            return nil
        }

        logger.log(
            "[Shazam] signature 생성 성공 - duration: \(signature.duration))s"
        )

        return try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<SHMatchedMediaItem?, Error>) in
            let delegate = ShazamDelegate { result in
                switch result {
                case .success(let item):
                    logger.log(
                        "[Shazam] 매칭 완료 - item: \(item?.title ?? "nil") / \(item?.artist ?? "nil")"
                    )
                    cont.resume(returning: item)
                case .failure(let error):
                    logger.log(
                        "[Shazam] 매칭 실패 - error: \(String(describing: error))"
                    )
                    cont.resume(throwing: error)
                }
            }

            session.delegate = delegate
            delegate.retainCycle = (session, delegate)

            logger.log("[Shazam] SHSession.match 호출")
            session.match(signature)
        }
    }

    private func makeSignature(from url: URL, maxDuration: TimeInterval)
        -> SHSignature?
    {
        logger.log(
            "[Shazam] makeSignature 시작 - url: \(url.lastPathComponent), maxDuration: \(maxDuration)s"
        )

        guard let file = try? AVAudioFile(forReading: url) else {
            logger.log("[Shazam] AVAudioFile 생성 실패")
            return nil
        }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        )!

        let srcFormat = file.processingFormat
        guard
            let converter = AVAudioConverter(from: srcFormat, to: targetFormat)
        else {
            logger.log("[Shazam] AVAudioConverter 생성 실패")
            return nil
        }

        let generator = SHSignatureGenerator()
        let blockFrames: AVAudioFrameCount = 4096

        guard
            let srcBuf = AVAudioPCMBuffer(
                pcmFormat: srcFormat,
                frameCapacity: blockFrames
            ),
            let dstBuf = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: blockFrames
            )
        else {
            logger.log("[Shazam] 버퍼 생성 실패")
            return nil
        }

        file.framePosition = 0
        logger.log("[Shazam] file.length: \(file.length) frames")

        var accumulatedDuration: TimeInterval = 0
        var chunkIndex = 0

        let audioChunks = sequence(state: ()) { _ -> AVAudioPCMBuffer? in
            do {
                try file.read(into: srcBuf, frameCount: blockFrames)
            } catch {
                logger.log("[Shazam] 파일 읽기 에러: \(String(describing: error))")
                return nil
            }

            if srcBuf.frameLength == 0 {
                logger.log("[Shazam] 더 이상 읽을 프레임 없음 (EOF)")
                return nil
            }

            dstBuf.frameLength = 0
            let block: AVAudioConverterInputBlock = { _, outStatus in
                if srcBuf.frameLength == 0 {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                outStatus.pointee = .haveData
                return srcBuf
            }

            let status = converter.convert(
                to: dstBuf,
                error: nil,
                withInputFrom: block
            )

            guard status != .error, dstBuf.frameLength > 0 else {
                if status == .error {
                    logger.log("[Shazam] 변환 에러 발생")
                }
                return nil
            }

            let out = dstBuf.copy() as? AVAudioPCMBuffer
            srcBuf.frameLength = 0
            chunkIndex += 1
            return out
        }

        var appendedChunks = 0

        for buf in audioChunks {
            let seconds = Double(buf.frameLength) / targetFormat.sampleRate
            let nextAccumulated = accumulatedDuration + seconds

            if accumulatedDuration >= maxDuration {
                logger.log(
                    "[Shazam] maxDuration 도달 - 루프 종료 (accumulated=\(accumulatedDuration)s)"
                )
                break
            }

            accumulatedDuration = nextAccumulated

            do {
                try generator.append(buf, at: nil)
                appendedChunks += 1
            } catch {
                logger.log(
                    "[Shazam] Signature append 실패: \(String(describing: error))"
                )
                return nil
            }
        }

        logger.log(
            """
            [Shazam] makeSignature 종료 전
                     appendedChunks=\(appendedChunks)
                     finalAccumulated=\(accumulatedDuration)s
            """
        )

        let signature = generator.signature()

        return signature
    }
    
    private func generateTitleWithGPT(instruction: String, prompt: String) async
        -> String?
    {

        guard
            let apiKey = Bundle.main.object(
                forInfoDictionaryKey: "GPT_API_KEY"
            ) as? String
        else { return nil }

        let api = ChatGPTAPI(
            apiKey: apiKey
        )

        guard
            let response = try? await api.sendMessage(
                text: prompt,
                model: "gpt-5-nano",
                systemText: instruction
            )
        else { return nil }

        return response
    }
}

private final class TopTagsObserver: NSObject, SNResultsObserving {
    private let topK: Int
    private let minConfidence: Double
    private var bestConfidenceById: [String: Double] = [:]
    private let completion: ([String]) -> Void

    init(
        topK: Int = 3,
        minConfidence: Double = 0.7,
        completion: @escaping ([String]) -> Void
    ) {
        self.topK = topK
        self.minConfidence = minConfidence
        self.completion = completion
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }

        for classification in result.classifications {
            let identifier = classification.identifier
            let confidence = classification.confidence

            guard confidence >= minConfidence else { continue }

            if let current = bestConfidenceById[identifier] {
                bestConfidenceById[identifier] = max(current, confidence)
            } else {
                bestConfidenceById[identifier] = confidence
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("Sound analysis failed: \(error)")
    }

    func requestDidComplete(_ request: SNRequest) {
        let topTags =
            bestConfidenceById
            .sorted { $0.value > $1.value }
            .prefix(topK)
            .map { $0.key }

        completion(topTags)
    }
}

private final class ShazamDelegate: NSObject, SHSessionDelegate {
    typealias MatchHandler = (Result<SHMatchedMediaItem?, Error>) -> Void
    private let handler: MatchHandler

    var retainCycle: (SHSession, ShazamDelegate)?

    init(handler: @escaping MatchHandler) {
        self.handler = handler
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        let item = match.mediaItems.first
        handler(.success(item))
        retainCycle = nil
    }

    func session(
        _ session: SHSession,
        didNotFindMatchFor signature: SHSignature,
        error: Error?
    ) {
        if let error {
            handler(.failure(error))
        } else {
            handler(.success(nil))
        }
        retainCycle = nil
    }
}
