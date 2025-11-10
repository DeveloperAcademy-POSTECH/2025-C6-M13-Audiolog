//
//  TitleGuide.swift
//  Audiolog
//
//  Created by 성현 on 11/9/25.
//

import Foundation
import FoundationModels

// MARK: - Public API

enum TitleGuide {
    @MainActor
    static func generateTitle(
        for recording: Recording,
        using session: LanguageModelSession,
        temperature: Double = 0.35,
        tagWeights: [String: Int]? = nil,
        policy: TitlePolicy
    ) async -> String? {

        let ctxObj = TitleContext(recording: recording, weights: tagWeights)
        let ctxJSON = ctxObj.toJSON()

        let prompt = buildUserPrompt(
            contextJSON: ctxJSON,
            hasWalkingCues: ctxObj.hasWalkingCues,
            primaryTag: ctxObj.primaryTag ?? ""
        )

        var candidates: [String] = []
        let N = 4
        let opts = GenerationOptions(temperature: temperature)

        for _ in 0..<N {
            do {
                let res = try await session.respond(options: opts) {
                    Prompt(prompt)
                }
                let t = res.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !t.isEmpty, !t.contains("\n") {
                    candidates.append(t)
                }

            } catch {
                let msg = error.localizedDescription.lowercased()
                if msg.contains("unsupported language")
                    || msg.contains("language")
                {
                    let fallback = """
                        한국어 한 문장 제목만 출력하세요. 따옴표/이모지/해시태그 금지.
                        입력:
                        \(ctxJSON)
                        출력: 한국어 한 문장.
                        """
                }
            }
        }

        guard !candidates.isEmpty else { return nil }

        let scored =
            candidates
            .map {
                (
                    title: $0,
                    score: score(title: $0, ctx: ctxObj, policy: policy)
                )
            }
            .sorted { $0.score > $1.score }

        return scored.first?.title
    }
}

// MARK: - Generated schema

@Generable
struct GuidedTitle {
    @Guide(description: "한국어 한 문장 제목만 출력. 줄바꿈/따옴표/이모지/해시태그/라벨 금지.")
    var title: String
}

// MARK: - Context (ko-keys)

private struct TitleContext: Encodable {
    let primaryTag: String?
    let secondaryTag: String?
    let hintTags: [String]
    let tagWeights: [String: Int]?
    let location: String?
    let dialog: String?
    let bgmTitle: String?
    let bgmArtist: String?

    let ratios: [String: Double]
    let primaryRatio: Double
    let speechRatio: Double

    let hasVoice: Bool
    let hasWaterAllowed: Bool
    let hasLocation: Bool
    let hasWalkingCues: Bool

    enum CodingKeys: String, CodingKey {
        case primaryTag = "주태그"
        case secondaryTag = "부태그"
        case hintTags = "힌트태그"
        case tagWeights = "태그가중치"
        case location = "위치"
        case dialog = "전사"
        case bgmTitle = "배경음악제목"
        case bgmArtist = "배경음악아티스트"
        case ratios = "태그비율"
        case primaryRatio = "주태그비율"
        case speechRatio = "음성비율"
        case hasVoice = "음성유무"
        case hasWaterAllowed = "물/파도허용"
        case hasLocation = "위치제공됨"
    }

    init(recording: Recording, weights: [String: Int]?) {
        self.tagWeights = weights

        let ordered: [String]
        let ratiosDict: [String: Double]
        if let w = weights, !w.isEmpty {
            let total = max(1, w.values.reduce(0, +))
            ratiosDict = w.mapValues { Double($0) / Double(total) }
            ordered = w.sorted { ($0.value, $0.key) > ($1.value, $1.key) }.map {
                $0.key
            }
        } else {
            ordered = (recording.tags ?? [])
            ratiosDict = [:]
        }
        self.ratios = ratiosDict

        primaryTag = ordered.first
        secondaryTag = ordered.dropFirst().first
        hintTags = Array(ordered.dropFirst(2).prefix(3))

        if let raw = recording.dialog?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !raw.isEmpty {
            dialog = raw.split(separator: "\n").prefix(3).joined(separator: " ")
        } else {
            dialog = nil
        }

        location = recording.location
        bgmTitle = recording.bgmTitle
        bgmArtist = recording.bgmArtist

        func ratio(for containsKeys: [String]) -> Double {
            guard !ratiosDict.isEmpty else { return 0 }
            let keys = ratiosDict.keys.map { $0.lowercased() }
            var r: Double = 0
            for (k, v) in ratiosDict {
                let lk = k.lowercased()
                if containsKeys.contains(where: { lk.contains($0) }) {
                    r = max(r, v)
                }
            }
            return r
        }

        primaryRatio = (primaryTag.flatMap { ratiosDict[$0] } ?? 0)
        speechRatio = ratio(for: ["speech", "vocal", "singing"])

        hasVoice = speechRatio >= 0.25

        hasWaterAllowed =
            ratio(for: ["waves", "wave", "water", "ocean", "sea"]) >= 0.15

        hasWalkingCues =
            ratio(for: ["footsteps", "walking", "walk", "jog", "stroll"])
            >= 0.15

        hasLocation = (recording.location?.isEmpty == false)
    }

    func toJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        return (try? String(data: enc.encode(self), encoding: .utf8)) ?? "{}"
    }
}

// MARK: - Policy Model

struct TitlePolicy: Codable {
    let policyVersion: String
    let lang: String
    let guardrails: [String]
    let priorityRules: PriorityRules
    let walkingConstraints: WalkingConstraints
    let speechBias: SpeechBias
    let specialCases: [SpecialCase]
    let fewShots: [FewShot]

    struct PriorityRules: Codable {
        let usePrimaryTagAsMainConcept: Bool
        let useSecondaryTagAsHint: Bool
        let useHintTagsAsMoodOnly: Bool
        let banNewContextFromHintTags: Bool
    }
    struct WalkingConstraints: Codable {
        let requireWalkingCuesForWalkWords: Bool
        let walkWords: [String]
    }
    struct SpeechBias: Codable { let enableWhenPrimaryTagEquals: [String] }

    struct SpecialCase: Codable {
        let when: String
        let title: String?
        let titleWithName: String?
        let contains: [String]?
        let titleIfContains: [String: String]?
        let patterns: [String]?
        let titlesByTransport: [String: String]?
        let fallback: String?
        let titleTalk: String?
        let titleAmbient: String?
        let titleTopic: String?
        let titleMonologue: String?
        let mapByDialog: [String: String]?
        let scheduleKeywords: [String]?
        let titleSchedule: String?
        let titleScheduleWithName: String?
        let titleMeta: String?
        let titleTitleOnly: String?
    }

    struct FewShot: Codable {
        let input: [String: String?]
        let output: String
    }
}

// MARK: - Policy Loader (Bundle 전용 + 최소 fallback)

private enum TitlePolicyLoader {
    static func load() -> TitlePolicy {
        guard
            let url = Bundle.main.url(
                forResource: "TitlePolicy",
                withExtension: "json"
            )
        else {
            #if DEBUG
                assertionFailure(
                    "[TitlePolicy] TitlePolicy.json not found in bundle. Check filename/target membership/Copy Bundle Resources."
                )
            #endif
            fatalError("[TitlePolicy] TitlePolicy.json not found in bundle.")
        }

        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONDecoder().decode(TitlePolicy.self, from: data)
            return obj
        } catch {
            #if DEBUG
                assertionFailure(
                    "[TitlePolicy] Failed to decode TitlePolicy.json: \(error)"
                )
            #endif
            fatalError(
                "[TitlePolicy] Failed to decode TitlePolicy.json: \(error)"
            )
        }
    }
}

// MARK: - Prompt Builder (Policy → ICL few-shot)

private func buildUserPrompt(
    contextJSON: String,
    hasWalkingCues: Bool,
    primaryTag: String
) -> String {

    let walkLine = hasWalkingCues
    ? "- 보행 단서 충분: ‘산책/걷기’ 류 표현 사용 가능."
    : "- 보행 단서 부족: ‘산책/걷기’ 류 표현 사용 금지."

    // primaryTag가 speech 계열이면 ‘이번 턴’ 스피치 힌트만 살짝
    let maybeSpeechHint = primaryTag.lowercased().contains("speech")
    ? "- 주태그가 speech: 음성 비율이 충분할 때 대화/회의/인터뷰 축 선호."
    : ""

    return """
    아래는 이번 녹음의 컨텍스트(JSON)입니다.
    \(contextJSON)

    동적 규칙(이번 턴 전용):
    \(walkLine)
    \(maybeSpeechHint)

    위 컨텍스트를 반영하여 자연스럽고 간결한 한국어 한 문장 제목만 출력하세요.
    (출력은 한 줄, 형식 규칙은 이미 시스템에 설정되어 있음)
    """
}

private func makeFewShots(from policy: TitlePolicy) -> [(
    inputJSON: String, output: String
)] {
    var items: [(String, String)] = []

    // 1) 정책에 명시된 fewShots 우선 (nil 값 제거하여 직렬화)
    for fs in policy.fewShots {
        var dict: [String: Any] = [:]
        for (k, v) in fs.input {
            if let value = v { dict[k] = value }
        }
        if let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: []
        ),
            let json = String(data: data, encoding: .utf8)
        {
            items.append((json, fs.output))
        }
    }

    // 2) specialCases도 간단 대표 예시로 변환 (너무 많아지지 않게 최소화)
    for sc in policy.specialCases {
        switch sc.when {
        case "interview":
            if let out = sc.title {
                items.append((#"{"주태그":"speech","전사":"자기소개 부탁드립니다"}"#, out))
            }
            if let withName = sc.titleWithName {
                let o = withName.replacingOccurrences(of: "{name}", with: "민수")
                items.append((#"{"주태그":"speech","전사":"민수 씨, 인터뷰 시작하겠습니다"}"#, o))
            }
        case "waves":
            if let t = sc.titleTalk {
                items.append(
                    (#"{"주태그":"waves","부태그":"speech","전사":"사진 한 장 더 찍자"}"#, t)
                )
            }
            if let a = sc.titleAmbient {
                items.append((#"{"주태그":"waves"}"#, a))
            }
        case "musicDominant":
            if let meta = sc.titleMeta {
                let o =
                    meta
                    .replacingOccurrences(of: "{bgmTitle}", with: "Lo-fi beats")
                    .replacingOccurrences(of: "{bgmArtist}", with: "Playlist")
                items.append(
                    (
                        #"{"주태그":"music","부태그":"singing","배경음악제목":"Lo-fi beats","배경음악아티스트":"Playlist"}"#,
                        o
                    )
                )
            }
            if let fb = sc.fallback {
                items.append((#"{"주태그":"music"}"#, fb))
            }
        default:
            break
        }
    }

    items.shuffle()
    return Array(items.prefix(12))
}

// MARK: - Soft Reranking

private func score(title: String, ctx: TitleContext, policy: TitlePolicy)
    -> Double
{
    var s = 0.0
    let t = title

    // ratio helper
    func ratio(for keys: [String]) -> Double {
        guard !ctx.ratios.isEmpty else { return 0 }
        var r = 0.0
        for (k, v) in ctx.ratios {
            let lk = k.lowercased()
            if keys.contains(where: { lk.contains($0) }) {
                r = max(r, v)
            }
        }
        return r
    }

    let rSpeech = ctx.speechRatio
    let rWaves = ratio(for: ["waves", "wave", "water", "ocean", "sea"])
    let rMusic = ratio(for: [
        "music", "singing", "keyboard", "guitar", "piano", "instrument",
    ])
    let rRain = ratio(for: ["rain"])
    let rSiren = ratio(for: ["siren", "alarm", "beep"])

    // 1) 주태그/비중 기반 가점
    if let p = ctx.primaryTag?.lowercased() {
        // speech 계열
        if t.contains("대화") || t.contains("회의") || t.contains("인터뷰") {
            // speechRatio에 비례한 가점 (최대 +3.0)
            s += min(3.0, 4.0 * rSpeech)
            if p.contains("speech") { s += 0.8 }  // 주태그가 speech면 추가 가점
        }
        // music 계열
        if t.contains("음악") || t.contains("연주") {
            s += min(2.2, 3.0 * rMusic)
            if p.contains("music") { s += 0.6 }
        }
        // rain / waves / siren
        if t.contains("빗") { s += min(1.8, 2.5 * rRain) }
        if t.contains("파도") { s += min(1.8, 2.5 * rWaves) }
        if t.contains("사이렌") || t.contains("경보") { s += min(1.6, 2.0 * rSiren) }
    }

    // 2) 금지/불일치 감점
    if !ctx.hasVoice
        && (t.contains("대화") || t.contains("회의") || t.contains("인터뷰")
            || t.contains("혼잣말"))
    {
        s -= 5.0
    }
    if !ctx.hasWaterAllowed
        && (t.contains("파도") || t.contains("바다") || t.contains("해변"))
    {
        s -= 4.0
    }
    if !ctx.hasLocation && containsPlaceLikeWord(t) {
        s -= 5.0
    }
    // waves 단어인데 비중이 너무 낮음(12% 미만) → 추가 감점
    if (t.contains("파도") || t.contains("바다") || t.contains("해변"))
        && rWaves < 0.12
    {
        s -= 2.5
    }
    // 음악/연주인데 music 비중이 매우 낮음(12% 미만) → 추가 감점
    if (t.contains("음악") || t.contains("연주")) && rMusic < 0.12 {
        s -= 2.0
    }
    // ‘산책’ 단어인데 보행 단서 없음 → 강력 감점
    if (t.contains("산책") || t.contains("걷") || t.contains("발걸음")
        || t.contains("조깅")) && !ctx.hasWalkingCues
    {
        s -= 4.0
    }

    // 3) 형식/길이 보너스
    if !t.contains("  ") && t.count <= 22 { s += 0.5 }
    if !["\"", "“", "#", "…"].contains(where: t.contains) { s += 0.3 }

    return s
}

private func containsPlaceLikeWord(_ t: String) -> Bool {
    // 아주 간단한 휴리스틱: 흔한 지명/장소 표기
    let words = [
        "서울", "부산", "해운대", "강남", "종로", "카페", "역", "광장", "공원", "교회", "연습실",
        "스튜디오", "해변", "바다",
    ]
    return words.contains { t.contains($0) }
}
