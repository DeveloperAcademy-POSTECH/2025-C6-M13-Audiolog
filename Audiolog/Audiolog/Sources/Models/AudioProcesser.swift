//
//  AudioProcesser.swift
//  Audiolog
//
//  Created by 성현 on 11/6/25.
//

import AVFoundation
import Foundation
import FoundationModels
import Playgrounds
import SoundAnalysis
import Speech
import SwiftData
import UniformTypeIdentifiers

@Observable
class AudioProcesser: NSObject {
    private var session: LanguageModelSession
    private let titlePolicy: TitlePolicy

    override init() {
        // 0) 정책 로드
        let policy = AudioProcesser.loadTitlePolicyOnce()
        self.titlePolicy = policy

        // 1) 시스템 프롬프트(instructions) 구성: guardrails + hard bans + ratio + few-shots(shotBlock)
        let instructions = AudioProcesser.buildTitleInstructions(from: policy)

        // 2) 세션 생성 (시스템 프롬프트 주입)
        self.session = LanguageModelSession(
            instructions: instructions
        )

        super.init()
    }

    // 내부 상태
    private var analyzerRef: SNAudioFileAnalyzer?
    private var observerRef: ClassificationObserver?
    
    /// TitlePolicy → 시스템 프롬프트(instructions)

    private static func loadTitlePolicyOnce() -> TitlePolicy {
        guard
            let url = Bundle.main.url(
                forResource: "TitlePolicy",
                withExtension: "json"
            )
        else {
            fatalError("[TitlePolicy] TitlePolicy.json not found in bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TitlePolicy.self, from: data)
        } catch {
            fatalError("[TitlePolicy] Failed to decode: \(error)")
        }
    }

    // MARK: - Public entrypoint
    @MainActor
    func processAudio(for recording: Recording, modelContext: ModelContext)
        async
    {
        logStep(
            0,
            "processAudio 시작",
            [
                "recordingId": recording.id.uuidString,
                "fileURL": recording.fileURL.absoluteString,
                "duration": String(format: "%.3f", recording.duration),
            ]
        )

        do {
            // 0) 오디오 세션 최소 설정 (try?는 throw하지 않으므로 do/catch 제거)
            try? AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default
            )
            try? AVAudioSession.sharedInstance().setActive(true)
            logger.log("[AudioProcesser] (0) AVAudioSession OK")

            // 1) 변환/보장
            logStep(
                1,
                "파일 준비(분석 가능 포맷 보장) 시작",
                ["inputPath": recording.fileURL.path]
            )
            let safeURL = try await prepareAudioURL(recording.fileURL)
            logStep(
                1,
                "파일 준비 완료",
                ["safePath": safeURL.path]
            )

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

            recording.tags = top5

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

            // 3) 전사 (스피치/싱잉일 때만)
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
                    )
                    .prefix(120)
                    logger.log("[AudioProcesser] (3) 전사 미리보기: \(preview)")
                    try? modelContext.save()
                } else {
                    logger.log(
                        "[AudioProcesser] (3) 전사 스킵 또는 실패(에러는 상단에서 이미 로깅됨)"
                    )
                }
            } else {
                logger.log("[AudioProcesser] (3) hasVoice=false 전사 스킵")
            }

            // TODO: music, singing일 때, 샤잠킷 구동하는 부분

            // 4) 타이틀 생성
            logStep(4, "타이틀 생성 시작(TitleGuide)", [:])
            if let title = await TitleGuide.generateTitle(
                for: recording,
                using: session,
                temperature: 0.35,
                tagWeights: stats,  // ⬅️ 한 번만 전달
                policy: self.titlePolicy  // ⬅️ 주입된 정책 사용
            ) {
                recording.title = title
                recording.isTitleGenerated = true
                logStep(4, "타이틀 생성 완료", ["title": title])
            } else {
                logger.log(
                    "[AudioProcesser] (4) TitleGuide.generateTitle 실패 (nil)"
                )
            }

            // 5) 최종 저장
            logStep(5, "최종 저장 시작", [:])
            try modelContext.save()
            logStep(5, "최종 저장 완료", ["recordingId": recording.id.uuidString])

        } catch {
            // 실패는 조용히 로깅 수준으로 처리. 필요 시 에러 전달 구조로 확장 가능.
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
        logger.log("[AudioProcesser] (1) prepareAudioURL 입력: \(debugURL(url))")
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
            logger.log("[AudioProcesser] (1) exportToM4A 성공: \(debugURL(out))")
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
                "[AudioProcesser] (1) AVAssetExport FAIL out=\(debugURL(out))"
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
        logger.log("[AudioProcesser] (2) analyzeSound 입력: \(debugURL(url))")

        let analyzer: SNAudioFileAnalyzer = try SNAudioFileAnalyzer(url: url)
        let request: SNClassifySoundRequest = try SNClassifySoundRequest(
            classifierIdentifier: .version1
        )
        request.windowDuration = CMTimeMakeWithSeconds(
            1.5,
            preferredTimescale: 44100
        )

        var collected: [ClassificationItem] = []
        let cont = AnalysisContinuation()
        let observer = ClassificationObserver { result, finished in
            switch result {
            case .success(let items):
                collected.append(contentsOf: items)
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
            observer.finish()
        } catch { observer.fail(error) }
        try await cont.wait()

        // 집계
        var labelStats: [String: Int] = [:]
        var hasVoice = false
        for it in collected {
            labelStats[it.label, default: 0] += 1
            let l = it.label.lowercased()
            if (l.contains("speech") || l.contains("singing")
                || l.contains("vocal")) && it.confidence >= 0.40
            {
                hasVoice = true
            }
        }

        logger.log(
            "[AudioProcesser] (2) 집계 결과: totalFrames=\(collected.count) uniqueLabels=\(labelStats.count)"
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
    // TODO: 샤잠킷 함수

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
        logger.log(msg)
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

private extension AudioProcesser {
    static func buildTitleInstructions(from p: TitlePolicy) -> String {
        let guardrails = p.guardrails.map { "• \($0)" }.joined(separator: "\n")

        let ratioPrinciples = """
        비중(태그비율) 원칙:
        - 주태그 비율이 35% 이상이면 제목의 핵심 콘셉트로 반드시 반영
        - 20~35% 구간은 맥락(전사/특수케이스/위치)과 조화롭게 선택 반영
        - 12% 미만 태그 단어는 제목에 직접 쓰지 말고 분위기 힌트로만 사용
        """

        let hardBans = """
        금지 규칙(MUST NOT):
        - 입력 JSON에 '위치'가 없으면 지명/장소(부산/해운대/서울/카페 등) 절대 금지
        - '음성유무'가 false면 말/대화/회의/인터뷰/독백 등 발화 관련 단어 금지
        - '물/파도허용'이 false면 파도/바다/해변 관련 단어 금지
        - 입력에 없는 인명/행사명/지명/곡명/가수 생성 금지(추정/창작 금지)
        """

        // 보행/스피치 ‘일반 지침’(세부 허용/금지는 유저 프롬프트에서 플래그로 제어)
        let walkingGeneral = p.walkingConstraints.requireWalkingCuesForWalkWords
        ? "보행 단어(\(p.walkingConstraints.walkWords.joined(separator: ", ")))는 보행 단서가 충분할 때만 허용."
        : ""

        let speechGeneral = !p.speechBias.enableWhenPrimaryTagEquals.isEmpty
        ? "주태그가 \(p.speechBias.enableWhenPrimaryTagEquals.joined(separator: "/"))일 때 음성 비율이 충분하면 대화/회의/인터뷰 축을 선호."
        : ""

        // shotBlock: TitlePolicy.fewShots → 시스템 프롬프트에 포함
        let shotBlock = compactFewShots(from: p)

        return """
        모든 출력은 한국어 한 문장. 따옴표/이모지/해시태그/접두 라벨/줄바꿈 금지.
        힌트태그로 새로운 맥락을 만들지 말 것(추가 설정/상상 금지).

        제목 작성 지향:
        \(guardrails)

        \(hardBans)

        \(ratioPrinciples)

        \(walkingGeneral)
        \(speechGeneral)

        예시(Few-shot, 형식 참고용):
        \(shotBlock)
        """
    }

    /// TitlePolicy.fewShots를 system용 shotBlock 문자열로 압축
    static func compactFewShots(from p: TitlePolicy) -> String {
        guard !p.fewShots.isEmpty else { return "- (없음)" }
        // 너무 길어질 수 있으니 6개 정도만(원문에서 이미 적당하면 전체 사용도 무방)
        let items = p.fewShots.prefix(6).map { fs -> String in
            // nil 값 제거한 JSON 한 줄
            var dict: [String: Any] = [:]
            fs.input.forEach { k, v in if let v { dict[k] = v } }
            let json = (try? JSONSerialization.data(withJSONObject: dict))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return "입력: \(json)\n출력: \(fs.output)"
        }
        return items.joined(separator: "\n\n")
    }
}
