//
//  AudioProcesser.swift
//  Audiolog
//
//  Created by 성현 on 11/6/25.
//

@preconcurrency import AVFoundation
import Foundation
import FoundationModels
import Playgrounds
import ShazamKit
import SoundAnalysis
import Speech
import SwiftData
import UniformTypeIdentifiers
import os

actor AudioProcesser {
    private var session: LanguageModelSession

    private var lastTask: Task<Void, Never>?
    private var inflight: Set<UUID> = []

    private let logger = Logger()

    init() {
        let baseInstructions = """
        너는 녹음 메모에 붙일 한국어 제목을 만들어 주는 도우미야.

        규칙:
        - 항상 한국어 한 문장만 출력해
        - 줄바꿈, 따옴표, 이모지, 해시태그, 접두 라벨을 쓰지 마
        - 입력 JSON에 없는 사람 이름/장소/곡명/행사 이름은 새로 만들지 마
        - 음성 비율이 낮으면 '대화/회의/인터뷰/혼잣말' 같은 표현은 피하고, 환경 소리 중심으로 표현해
        - 파도/바다/해변 소리가 거의 없으면 그런 단어는 쓰지 마
        - 걷는 소리가 거의 없으면 '산책/걷기/조깅' 같은 표현은 쓰지 마
        """

        let fewShotBlock = AudioProcesser.loadFewShotBlock()

        let instructions: String
        if fewShotBlock.isEmpty {
            instructions = baseInstructions
        } else {
            instructions = """
            \(baseInstructions)

            예시(Few-shot, 형식 참고용):
            \(fewShotBlock)
            """
        }

        self.session = LanguageModelSession(instructions: instructions)
    }

    func enqueueProcess(for recording: Recording, modelContext: ModelContext) {
        let rid = recording.id
        if inflight.contains(rid) {
            return
        }
        inflight.insert(rid)

        let prev = lastTask
        let task = Task { [weak self] in
            if let prev { _ = await prev.value }
            guard let self else { return }
            defer { Task { await self.finish(rid) } }

            await self.runProcess(for: recording, modelContext: modelContext)
        }
        lastTask = task
    }

    private func finish(_ id: UUID) {
        inflight.remove(id)
    }

    // 내부 상태
    private var analyzerRef: SNAudioFileAnalyzer?
    private var observerRef: ClassificationObserver?

    // MARK: - Public entrypoint
    private func runProcess(
        for recording: Recording,
        modelContext: ModelContext
    ) async {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        logStep(
            0,
            "processAudio 시작",
            [
                "recordingId": recording.id.uuidString,
                "fileURL": fileURL.absoluteString,
                "duration": String(format: "%.3f", recording.duration),
            ]
        )

        do {
            try? AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default
            )
            try? AVAudioSession.sharedInstance().setActive(true)
            logger.log("[AudioProcesser] (0) AVAudioSession OK")

            // 1) 포맷 보장
            logStep(1, "파일 준비(분석 가능 포맷 보장) 시작", ["inputPath": fileURL.path])
            let safeURL = try await prepareAudioURL(fileURL)
            logStep(1, "파일 준비 완료", ["safePath": safeURL.path])

            // 2) 사운드 분류
            logStep(2, "사운드 분류 시작", ["url": safeURL.lastPathComponent])
            let (stats, hasVoice) = try await analyzeSound(url: safeURL)
            let totalCount = stats.values.reduce(0, +)
            let top5Pairs = stats.sorted { $0.value > $1.value }.prefix(5)
            let top5 = top5Pairs.map { $0.key }
            let top5Ratios = top5Pairs.map { (label, count) -> String in
                let ratio =
                    totalCount > 0
                    ? Double(count) / Double(totalCount) * 100 : 0
                return String(format: "%@ %.1f%%", label, ratio)
            }

            // SwiftData write는 메인액터에서
            await MainActor.run {
                recording.tags = top5
            }
            logStep(
                2,
                "사운드 분류 완료",
                [
                    "top5": top5.joined(separator: ", "),
                    "ratios": top5Ratios.joined(separator: " | "),
                    "hasVoice": "\(hasVoice)",
                    "totalFrames": "\(totalCount)",
                ]
            )

            do {
                try modelContext.save()
                logger.log("[AudioProcesser] (2.5) 중간 저장 OK")
            } catch {
                logNSError(error, prefix: "(2.5) modelContext.save()")
            }

            // 3) 전사
            if hasVoice {
                logStep(3, "전사 시작", ["locale": "ko_KR"])
                if let transcript = try? await transcribe(
                    url: safeURL,
                    localeIdentifier: "ko_KR"
                ) {
                    recording.dialog = transcript
                    logStep(3, "전사 완료", ["length": "\(transcript.count)"])
                    let preview = transcript.replacingOccurrences(
                        of: "\n",
                        with: " "
                    ).prefix(120)
                    logger.log("[AudioProcesser] (3) 전사 미리보기: \(preview)")
                    try modelContext.save()
                } else {
                    logger.log("[AudioProcesser] (3) 전사 스킵 또는 실패")
                }
            } else {
                logger.log("[AudioProcesser] (3) hasVoice=false 전사 스킵")
            }

            // 4) 샤잠킷
            logStep(
                4,
                "ShazamKit 매칭 시작",
                ["url": safeURL.lastPathComponent]
            )
            do {
                if let item = try await identifyMusic(from: safeURL) {
                    await MainActor.run {
                        recording.bgmTitle =
                            item.title ?? recording.bgmTitle
                        recording.bgmArtist =
                            item.artist ?? recording.bgmArtist
                    }
                    logger.log(
                        "[AudioProcesser] (4.5) ShazamKit 매칭: \(item.title ?? "?") - \(item.artist ?? "?")"
                    )
                    try modelContext.save()
                } else {
                    logger.log("[AudioProcesser] (4.5) ShazamKit 매칭 결과 없음")
                }
            } catch {
                logNSError(error, prefix: "(4.5) ShazamKit")
            }

            // 5) 타이틀 생성
            logStep(5, "타이틀 생성 시작(TitleGuide)", [:])
            if let title = await TitleGuide.generateTitle(
                for: recording,
                using: session,
                temperature: 0.35,
                tagWeights: stats
            ) {
                await MainActor.run {
                    recording.title = title
                    recording.isTitleGenerated = true
                }
                logStep(5, "타이틀 생성 완료", ["title": title])
            } else {
                logger.log(
                    "[AudioProcesser] (5) TitleGuide.generateTitle 실패 (nil)"
                )
            }

            // 6) 최종 저장
            logStep(6, "최종 저장 시작", [:])
            try modelContext.save()
            logStep(6, "최종 저장 완료", ["recordingId": recording.id.uuidString])

        } catch {
            let ns = error as NSError
            logger.log(
                "[AudioProcesser] ERROR processAudio: \(ns.domain)(\(ns.code)) \(ns.localizedDescription) userInfo=\(ns.userInfo)"
            )
        }

        logger.log("[AudioProcesser] processAudio 종료")
    }

    // MARK: - File preparation (mov/mp4 → m4a 보장)
    /// 분석 가능한 오디오 URL 보장: 트랙 없으면 에러, 필요 시 M4A로 추출
    private func prepareAudioURL(_ url: URL) async throws -> URL {
        logger.log(
            "[AudioProcesser] (1) prepareAudioURL 입력: \(self.debugURL(url))"
        )
        let asset = AVURLAsset(url: url)

        // 가용성 로깅 (deprecated 속성 대신 load API 사용)
        let isReadable: Bool
        let isExportable: Bool
        do {
            isReadable = try await asset.load(.isReadable)
        } catch {
            self.logNSError(error, prefix: "(1) load(.isReadable)")
            throw error
        }
        do {
            isExportable = try await asset.load(.isExportable)
        } catch {
            self.logNSError(error, prefix: "(1) load(.isExportable)")
            throw error
        }
        logger.log(
            "[AudioProcesser] (1) AVURLAsset flags readable=\(isReadable) exportable=\(isExportable)"
        )

        do {
            let tracks = try await asset.load(.tracks)
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            guard !audioTracks.isEmpty else {
                logger.log("[AudioProcesser] (1) 오디오 트랙 없음")
                throw APFailure("해당 파일에 오디오 트랙이 없습니다.")
            }
        } catch {
            logNSError(error, prefix: "(1) load(.tracks)")
            throw error
        }

        if url.pathExtension.lowercased() == "m4a" {
            logger.log("[AudioProcesser] (1) 이미 m4a, 변환 생략")
            return url
        }

        do {
            let out = try await exportToM4A(
                from: asset,
                basename: url.deletingPathExtension().lastPathComponent
            )
            logger.log(
                "[AudioProcesser] (1) exportToM4A 성공: \(self.debugURL(out))"
            )
            return out
        } catch {
            logNSError(error, prefix: "(1) exportToM4A")
            throw error
        }
    }

    private func exportToM4A(from asset: AVURLAsset, basename: String)
        async throws -> URL
    {
        guard
            let export = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetAppleM4A
            )
        else {
            throw APFailure("오디오 추출 세션 생성 실패")
        }
        let out = temporaryM4AURL("\(basename)-ap")
        export.outputURL = out
        export.outputFileType = .m4a

        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            logNSError(error, prefix: "(1) load(.duration)")
            throw error
        }
        export.timeRange = CMTimeRange(start: .zero, duration: duration)

        logger.log(
            "[AudioProcesser] (1) AVAssetExport 시작 → \(out.lastPathComponent) duration=\(CMTimeGetSeconds(duration))s"
        )

        do {
            try await export.export(to: out, as: .m4a)
        } catch {
            logNSError(error, prefix: "(1) AVAssetExport")
            logger.log(
                "[AudioProcesser] (1) AVAssetExport FAIL out=\(self.debugURL(out))"
            )
            throw error
        }

        return out
    }

    private func temporaryM4AURL(_ basename: String) -> URL {
        let tmp = FileManager.default.temporaryDirectory
        let safe = basename.replacingOccurrences(
            of: "[/:\\?%*|\"<>]",
            with: "-",
            options: .regularExpression
        )
        return tmp.appendingPathComponent(
            "\(safe)-\(UUID().uuidString.prefix(6)).m4a"
        )
    }

    // MARK: - Sound Analysis
    private func analyzeSound(url: URL) async throws -> ([String: Int], Bool) {
        logger.log(
            "[AudioProcesser] (2) analyzeSound 입력: \(self.debugURL(url))"
        )

        let analyzer = try SNAudioFileAnalyzer(url: url)
        let request = try SNClassifySoundRequest(
            classifierIdentifier: .version1
        )

        // A-1) 윈도우 짧게 (기본 1.5s → 0.9s 권장)
        request.windowDuration = CMTimeMakeWithSeconds(
            0.9,
            preferredTimescale: 44100
        )

        // ---- 컬렉션 구조: 프레임별 top2 + 에너지 ----
        struct FrameVote {
            let time: CMTimeRange
            let top1: (label: String, conf: Double)
            let top2: (label: String, conf: Double)?
            let rms: Float
        }
        var frames: [FrameVote] = []

        // C-1) 파일에서 대충의 RMS를 재계산하는 유틸 (짧은 슬라이스 에너지)
        func rmsOf(_ buffer: AVAudioPCMBuffer) -> Float {
            guard let ch = buffer.floatChannelData?[0], buffer.frameLength > 0
            else { return 0 }
            let n = Int(buffer.frameLength)
            var acc: Float = 0
            for i in 0..<n {
                let v = ch[i]
                acc += v * v
            }
            return sqrt(acc / Float(n))
        }

        // 결과 수집
        let cont = AnalysisContinuation()
        let observer = ClassificationObserver { result, finished in
            switch result {
            case .success(let items):
                let sorted = items.sorted { $0.confidence > $1.confidence }
                if let first = sorted.first {
                    let second = sorted.dropFirst().first
                    frames.append(
                        FrameVote(
                            time: first.timeRange,
                            top1: (first.label, first.confidence),
                            top2: second.map { ($0.label, $0.confidence) },
                            rms: 1.0  // (정확 RMS는 아래 오프라인 추정으로 대체 가능)
                        )
                    )
                }
            case .failure(let error):
                self.logNSError(error, prefix: "(2) observer")
                cont.resumeThrowing(error)
                return
            }
            if finished { cont.resume() }
        }

        try analyzer.add(request, withObserver: observer)
        self.analyzerRef = analyzer
        self.observerRef = observer
        do {
            try await analyzer.analyze()
            await observer.finish()
        } catch { await observer.fail(error) }
        try await cont.wait()

        // A-2) 마진/문턱 적용 + B) 런 길이 스무딩
        let minConf: Double = 0.55
        let minMargin: Double = 0.15
        let minRun: Int = 2  // 같은 라벨 최소 2프레임 연속일 때만 인정

        // 유효 프레임으로 필터링
        let filtered: [String?] = frames.map { f in
            guard f.top1.conf >= minConf else { return nil }
            let m = f.top1.conf - (f.top2?.conf ?? 0.0)
            guard m >= minMargin else { return nil }
            // C-3) 에너지 컷 (정확 측정 시: if f.rms < 0.01 { return nil })
            return f.top1.label
        }

        // 런 길이 기반 확정 라벨 시퀀스 생성
        var confirmed: [String] = []
        var i = 0
        while i < filtered.count {
            let current = filtered[i]
            if current == nil {
                i += 1
                continue
            }
            var j = i
            while j < filtered.count && filtered[j] == current { j += 1 }
            let runLen = j - i
            if runLen >= minRun, let label = current {
                confirmed.append(
                    contentsOf: Array(repeating: label, count: runLen)
                )
            }
            i = j
        }

        // 집계
        var labelStats: [String: Int] = [:]
        var hasVoice = false
        for label in confirmed {
            labelStats[label, default: 0] += 1
            let l = label.lowercased()
            if l.contains("speech") || l.contains("singing")
                || l.contains("vocal")
            {
                hasVoice = true
            }
        }

        logger.log(
            "[AudioProcesser] (2) 집계 결과(후처리): frames=\(frames.count) confirmed=\(confirmed.count) unique=\(labelStats.count)"
        )
        return (labelStats, hasVoice)
    }

    // MARK: - Transcription
    private func transcribe(url: URL, localeIdentifier: String) async throws
        -> String
    {
        logger.log(
            "[AudioProcesser] (3) transcribe 시작: \(url.lastPathComponent) locale=\(localeIdentifier)"
        )

        guard
            let recognizer = SFSpeechRecognizer(
                locale: Locale(identifier: localeIdentifier)
            )
        else {
            throw APFailure("해당 로케일에서 인식기를 초기화할 수 없음")
        }
        guard recognizer.isAvailable else {
            throw APFailure("지금 인식 서비스 사용 불가")
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        return try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<String, Error>) in
            var finalText = ""
            var finished = false
            let task = recognizer.recognitionTask(with: request) {
                result,
                error in
                if let error {
                    self.logNSError(error, prefix: "(3) recognitionTask")
                    guard !finished else { return }
                    finished = true
                    cont.resume(throwing: error)
                    return
                }
                guard let result else { return }
                let raw = result.bestTranscription.formattedString
                finalText = Self.paragraphized(raw)
                if result.isFinal {
                    guard !finished else { return }
                    finished = true
                    cont.resume(returning: finalText)
                }
            }
            // 취소 안전
            Task {
                await Task.yield()
                if Task.isCancelled { task.cancel() }
            }
        }
    }

    private static func paragraphized(_ raw: String) -> String {
        // 간단한 문장부호 기준 줄바꿈
        return
            raw
            .replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: ". ", with: ".\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Music identifier
    private func identifyMusic(from url: URL) async throws
        -> SHMatchedMediaItem?
    {
        let signature = try makeSignature(from: url)

        return try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<SHMatchedMediaItem?, Error>) in
            let session = SHSession()
            let delegate = ShazamDelegate { result in
                switch result {
                case .success(let item):
                    cont.resume(returning: item)
                case .failure(let error):
                    let ns = error as NSError
                    self.logger.log(
                        "[AudioProcesser] (4.5) ShazamKit 실패: domain=\(ns.domain) code=\(ns.code) msg=\(ns.localizedDescription) userInfo=\(ns.userInfo)"
                    )
                    cont.resume(throwing: error)
                }
            }
            session.delegate = delegate
            delegate.retainCycle = (session, delegate)

            logger.log("[AudioProcesser] (4) SHSession.match 시작")

            session.match(signature)
        }
    }

    private func makeSignature(from url: URL) throws -> SHSignature {
        let file = try AVAudioFile(forReading: url)

        // 타깃 포맷: 44.1kHz, 모노, Float32, deinterleaved
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!

        let srcFormat = file.processingFormat
        let converter = AVAudioConverter(from: srcFormat, to: targetFormat)
        guard let converter else { throw APFailure("오디오 포맷 변환기 생성 실패") }

        let gen = SHSignatureGenerator()
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
        else { throw APFailure("PCMBuffer 생성 실패") }

        let minFrames = AVAudioFramePosition(targetFormat.sampleRate * 3.0)
        var totalOutFrames: AVAudioFramePosition = 0

        file.framePosition = 0
        var isEOF = false

        while !isEOF {
            do {
                try file.read(into: srcBuf, frameCount: blockFrames)
            } catch {
                if srcBuf.frameLength == 0 {
                    isEOF = true
                    break
                }
                throw error
            }

            if srcBuf.frameLength == 0 {
                isEOF = true
                break
            }

            dstBuf.frameLength = 0
            let inputBlock: AVAudioConverterInputBlock = {
                inNumPackets,
                outStatus in
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
                withInputFrom: inputBlock
            )
            guard status != .error else { throw APFailure("오디오 변환 실패") }

            if dstBuf.frameLength > 0 {
                try gen.append(dstBuf, at: nil)
                totalOutFrames += AVAudioFramePosition(dstBuf.frameLength)
            }

            // 다음 루프에서 입력 버퍼를 새로 채우도록 frameLength 0으로 리셋
            srcBuf.frameLength = 0
        }

        if totalOutFrames < minFrames {
            logger.log("[AudioProcesser] ShazamKit: 변환된 유효 오디오가 3초 미만(매칭 난이도↑)")
        }

        return gen.signature()
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

    // MARK: - Debug helpers

    /// 단계를 번호와 함께 기록
    private func logStep(_ step: Int, _ title: String, _ info: [String: String])
    {
        let kv = info.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.log("[AudioProcesser] (\(step)) \(title) \(kv)")
    }

    /// 에러를 상세하게 기록
    private func logNSError(_ error: Error, prefix: String) {
        let ns = error as NSError
        var msg =
            "[AudioProcesser] \(prefix) ERROR \(ns.domain)(\(ns.code)) \(ns.localizedDescription)"
        if let r = ns.localizedFailureReason { msg += " | reason=\(r)" }
        if let s = ns.localizedRecoverySuggestion {
            msg += " | suggestion=\(s)"
        }
        if !ns.userInfo.isEmpty { msg += " | userInfo=\(ns.userInfo)" }
        logger.log("\(msg)")
    }

    /// 파일 경로/존재/사이즈/타임스탬프를 문자열로 요약
    private func debugURL(_ url: URL) -> String {
        let fm = FileManager.default
        var parts: [String] = []
        parts.append("path=\(url.path)")
        let exists = fm.fileExists(atPath: url.path)
        parts.append("exists=\(exists)")
        if exists, let attrs = try? fm.attributesOfItem(atPath: url.path) {
            if let size = attrs[.size] as? NSNumber {
                parts.append("size=\(size.uint64Value)B")
            }
            if let cdate = attrs[.creationDate] as? Date {
                parts.append("created=\(cdate)")
            }
            if let mdate = attrs[.modificationDate] as? Date {
                parts.append("modified=\(mdate)")
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Helper types

struct APFailure: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

private struct ClassificationItem {
    let label: String
    let confidence: Double
    let timeRange: CMTimeRange
}

private final class AnalysisContinuation {
    private var resumed = false
    private var continuation: CheckedContinuation<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation {
            (c: CheckedContinuation<Void, Error>) in
            if resumed {
                c.resume()
            } else {
                continuation = c
            }
        }
    }

    func resume() {
        guard !resumed else { return }
        resumed = true
        continuation?.resume()
        continuation = nil
    }

    func resumeThrowing(_ error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

/// SNResultsObserving 어댑터: 파일 분석 전 구간을 수집하고 종료 시그널을 전달
private class ClassificationObserver: NSObject, SNResultsObserving {
    private let handler: (Result<[ClassificationItem], Error>, Bool) -> Void
    private var finished = false

    init(handler: @escaping (Result<[ClassificationItem], Error>, Bool) -> Void)
    {
        self.handler = handler
    }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let r = result as? SNClassificationResult else { return }
        let items: [ClassificationItem] = r.classifications
            .filter { $0.confidence > 0.20 }
            .map {
                ClassificationItem(
                    label: $0.identifier,
                    confidence: $0.confidence,
                    timeRange: r.timeRange
                )
            }
        handler(.success(items), false)
    }

    func requestDidFail(_ request: SNRequest, withError error: Error) {
        guard !finished else { return }
        finished = true
        handler(.failure(error), true)
    }

    func requestDidComplete(_ request: SNRequest) {
        guard !finished else { return }
        finished = true
        handler(.success([]), true)
    }

    func finish() {
        guard !finished else { return }
        finished = true
        handler(.success([]), true)
    }

    func fail(_ error: Error) {
        guard !finished else { return }
        finished = true
        handler(.failure(error), true)
    }
}

private struct TitleFewShotBundle: Decodable {
    let fewShots: [TitleFewShot]
}

private struct TitleFewShot: Decodable {
    let input: [String: String]
    let output: String
}

extension AudioProcesser {
    /// 번들에서 TitleFewShots.json을 읽어 few-shot 텍스트 블럭으로 변환
    fileprivate static func loadFewShotBlock() -> String {
        guard
            let url = Bundle.main.url(
                forResource: "TitleFewShots",
                withExtension: "json"
            )
        else {
            return ""
        }

        do {
            let data = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(TitleFewShotBundle.self, from: data)
            guard !bundle.fewShots.isEmpty else {
                return ""
            }

            let lines: [String] = bundle.fewShots.map { shot in
                let jsonString: String
                if let d = try? JSONSerialization.data(
                    withJSONObject: shot.input,
                    options: [.withoutEscapingSlashes]
                ), let s = String(data: d, encoding: .utf8) {
                    jsonString = s
                } else {
                    jsonString = "{}"
                }

                return """
                입력: \(jsonString)
                출력: \(shot.output)
                """
            }

            return lines.joined(separator: "\n\n")
        } catch {
            let ns = error as NSError
            Logger().log(
                "[AudioProcesser] Failed to load TitleFewShots.json: \(ns.domain)(\(ns.code)) \(ns.localizedDescription)"
            )
            return ""
        }
    }
}
