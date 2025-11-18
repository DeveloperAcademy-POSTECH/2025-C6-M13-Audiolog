//
//  AudioProcesser.swift
//  Audiolog
//
//  Created by 성현 on 11/6/25.
//

@preconcurrency import AVFoundation
import FoundationModels
import ShazamKit
import SoundAnalysis
import Speech

@MainActor
@Observable
final class AudioProcesser {
    var isLanguageModelAvailable: Bool = true
    var languageModelSession: LanguageModelSession?

    init() {}

    func configureLanguageModelSession() async {
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

        self.languageModelSession = LanguageModelSession(
            instructions: "주어지는 오디오 파일의 메타데이터를 정확하게 요약해서 15자 이내의 한국어 제목을 생성한다."
        )
    }

    func generateTitle(recording: Recording) async {
        guard let languageModelSession else { return }

        var prompt = "[metadata] \n"

        if let dialog = recording.dialog, !dialog.isEmpty {
            prompt += "대화 내용: \(dialog) \n"
        }

        if let bgmArtist = recording.bgmArtist,
            let bgmTitle = recording.bgmTitle
        {
            prompt += "들리는 음악: \(bgmArtist)의 \(bgmTitle) \n"
        }

        if let location = recording.location {
            prompt += "장소: \(location) \n"
        }

        if let weather = recording.weather {
            prompt += "날씨: \(weather) \n"
        }

        if prompt == "[metadata] \n" {
            prompt +=
                "시간: \(recording.createdAt.formatted("a h:mm")) \n"
        }

        if let tags = recording.tags, !tags.isEmpty {
            prompt += "태그: \(tags.joined(separator: ", "))"
        }

        logger.log("[AudioProcessor] Prompt: \(prompt)")

        do {
            let response = try await languageModelSession.respond(to: prompt)
            let title = response.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            recording.title = title
            recording.isTitleGenerated = true
            logger.log("[AudioProcessor] Generated title: \(title)")
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

            let observer = TopTagsObserver(topK: 3, minConfidence: 0.7) {
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
                "[AudioProcesser] (4.5) ShazamKit 매칭: \(item.title ?? "?") - \(item.artist ?? "?")"
            )
        } else {
            logger.log("[AudioProcesser] (4.5) ShazamKit 매칭 결과 없음")
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
        guard let signature = makeSignature(from: url) else { return nil }

        return try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<SHMatchedMediaItem?, Error>) in
            let session = SHSession()
            let delegate = ShazamDelegate { result in
                switch result {
                case .success(let item):
                    cont.resume(returning: item)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            session.delegate = delegate
            delegate.retainCycle = (session, delegate)

            logger.log("[AudioProcesser] (4) SHSession.match 시작")

            session.match(signature)
        }
    }

    private func makeSignature(from url: URL) -> SHSignature? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!

        let srcFormat = file.processingFormat
        guard
            let converter = AVAudioConverter(from: srcFormat, to: targetFormat)
        else {
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
        else { return nil }

        file.framePosition = 0

        let audioChunks = sequence(state: ()) { _ -> AVAudioPCMBuffer? in
            do {
                try file.read(into: srcBuf, frameCount: blockFrames)
            } catch {
                return nil
            }

            if srcBuf.frameLength == 0 {
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
                return nil
            }

            let out = dstBuf.copy() as? AVAudioPCMBuffer
            srcBuf.frameLength = 0
            return out
        }

        for buf in audioChunks {
            do {
                try generator.append(buf, at: nil)
            } catch {
                return nil
            }
        }

        return generator.signature()
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
