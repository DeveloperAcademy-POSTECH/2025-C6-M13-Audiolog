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
    static func generateTitle(
        for recording: Recording,
        using session: LanguageModelSession,
        temperature: Double = 0.35,
        tagWeights: [String: Int]? = nil,
        policy: TitlePolicy
    ) async -> String? {

        let ctxObj = TitleContext(recording: recording, weights: tagWeights)
        let ctxJSON = ctxObj.toJSON()

        let maxRatio = ctxObj.ratios.values.max() ?? 0
        if maxRatio < 0.20 {
            return "분석 실패, 상황을 수정해주세요"
        }

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
                let raw = res.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !raw.isEmpty, !raw.contains("\n") else { continue }

                let allowLongMusic = allowsLongMusicTitle(
                    raw: raw,
                    recording: recording,
                    ctx: ctxObj
                )
                let short =
                    allowLongMusic
                    ? shrinkKoreanTitle(raw, limit: 64)
                    : shrinkKoreanTitle(raw, limit: 15)

                if !short.isEmpty {
                    candidates.append(short)
                }
            } catch {
                let msg = error.localizedDescription.lowercased()
                if msg.contains("unsupported language")
                    || msg.contains("language")
                {
                    // 로컬 폴백(한 줄 한국어)
                    let fallback = """
                        한국어 한 문장 제목만 출력하세요. 따옴표/이모지/해시태그 금지.
                        입력:
                        \(ctxJSON)
                        출력: 한국어 한 문장.
                        """
                    // (선택) fallback으로 한 번 더 시도하려면 여기서 session.respond 호출 가능
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

        if var best = scored.first?.title {
            // (C) 최종 방어 축약도 음악 메타 제목은 해제
            let allowLongMusicFinal = allowsLongMusicTitle(
                raw: best,
                recording: recording,
                ctx: ctxObj
            )
            if !allowLongMusicFinal {
                best = shrinkKoreanTitle(best, limit: 15)
            }

            if let loc = formatKoreanLocationSuffix(from: recording.location),
                !loc.isEmpty, !best.contains(loc)
            {
                best += ", \(loc)"
            }
            return best
        }
        return nil
    }
}

// 음악 메타 제목(가수-제목/제목, 가수)을 허용할지 판단
private func allowsLongMusicTitle(raw: String, recording: Recording, ctx: Any)
    -> Bool
{
    // 주/부 태그가 music/singing/instrument 계열이면 우선 가점
    let primary = (ctx as? TitleContext)?.primaryTag?.lowercased() ?? ""
    let musicy = [
        "music", "singing", "instrument", "song", "guitar", "piano", "keyboard",
        "drum",
    ]
    .contains { primary.contains($0) }

    // 녹음에서 이미 매칭된 BGM 메타가 있으면 그 문자열 포함 여부로 거의 확정
    let title = (recording.bgmTitle ?? "").trimmingCharacters(in: .whitespaces)
    let artist = (recording.bgmArtist ?? "").trimmingCharacters(
        in: .whitespaces
    )

    // "제목, 가수" 또는 "가수 - 제목" 같이 구분자가 들어간 경우 허용
    let looksLikeMetaSeparator =
        raw.contains(",") || raw.contains(" - ") || raw.contains("—")

    // BGM 메타가 있고, 원문에 둘 중 하나 이상이 포함되면 장문 허용
    let containsMeta =
        (!title.isEmpty && raw.contains(title))
        || (!artist.isEmpty && raw.contains(artist))

    return musicy && (containsMeta || looksLikeMetaSeparator)
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
    let dialog: String?
    let bgmTitle: String?
    let bgmArtist: String?

    let ratios: [String: Double]
    let primaryRatio: Double
    let speechRatio: Double

    let hasVoice: Bool
    let hasWaterAllowed: Bool
    let hasWalkingCues: Bool

    enum CodingKeys: String, CodingKey {
        case primaryTag = "주태그"
        case secondaryTag = "부태그"
        case hintTags = "힌트태그"
        case tagWeights = "태그가중치"
        case dialog = "전사"
        case bgmTitle = "배경음악제목"
        case bgmArtist = "배경음악아티스트"
        case ratios = "태그비율"
        case primaryRatio = "주태그비율"
        case speechRatio = "음성비율"
        case hasVoice = "음성유무"
        case hasWaterAllowed = "물/파도허용"
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

    let walkLine =
        hasWalkingCues
        ? "- 보행 단서 충분: ‘산책/걷기’ 류 표현 사용 가능."
        : "- 보행 단서 부족: ‘산책/걷기’ 류 표현 사용 금지."

    // primaryTag가 speech 계열이면 ‘이번 턴’ 스피치 힌트만 살짝
    let maybeSpeechHint =
        primaryTag.lowercased().contains("speech")
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

private func formatKoreanLocationSuffix(from location: String?) -> String? {
    guard let raw = location?.trimmingCharacters(in: .whitespacesAndNewlines),
        !raw.isEmpty
    else {
        logger.log("[LocationDebug] ❌ location이 비어있음")
        return nil
    }

    let toks =
        raw
        .replacingOccurrences(of: ",", with: " ")
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)

    if toks.isEmpty {
        return nil
    }

    // 접미사 목록
    let provinceSuffixes = ["특별자치도", "광역시", "특별시", "자치시", "자치도", "도"]
    let citySuffixes = ["특별자치시", "광역시", "특별시", "자치시", "시"]
    let districtSuffixes = ["구", "군"]
    let minorSuffixes = ["읍", "면", "동"]

    func strip(_ s: String, suffixes: [String]) -> String {
        for suf in suffixes.sorted(by: { $0.count > $1.count }) {
            if s.hasSuffix(suf) {
                return String(s.dropLast(suf.count))
            }
        }
        return s
    }

    // 토큰 내부에서 '...시' 추출 (예: "포항시지곡동" → ("포항시", "지곡동"))
    func splitCityInToken(_ token: String) -> (
        cityWithSuffix: String, rest: String
    )? {
        let citySufPattern = "(특별자치시|광역시|특별시|자치시|시)"
        let pattern = "^(.*?\(citySufPattern))(.*)$"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = token as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let m = regex.firstMatch(in: token, range: range),
                m.numberOfRanges >= 3
            {
                let cityWithSuffix = ns.substring(with: m.range(at: 1))
                let rest = ns.substring(with: m.range(at: 3))
                if !cityWithSuffix.isEmpty {
                    return (cityWithSuffix, rest)
                }
            }
        }
        return nil
    }

    // '구/군' 혹은 '읍/면/동'을 토큰에서 찾거나 내부 분리로 찾기
    func findAdminUnit(
        in tokens: [String],
        prefer: [String],  // ["구","군"] 우선
        fallback: [String]
    ) -> (found: String?, kind: String) {
        // 1) 직접 토큰 끝
        for t in tokens {
            if prefer.contains(where: { t.hasSuffix($0) }) {
                return (t, "prefer")
            }
        }
        // 2) 내부에 붙은 형태 (예: "남구효자동", "지곡동지곡로")
        if let rg = try? NSRegularExpression(pattern: "(.*?(구|군|읍|면|동))(.*)") {
            for t in tokens {
                let ns = t as NSString
                let range = NSRange(location: 0, length: ns.length)
                if let m = rg.firstMatch(in: t, range: range),
                    m.numberOfRanges >= 2
                {
                    let part = ns.substring(with: m.range(at: 1))
                    if prefer.contains(where: { part.hasSuffix($0) }) {
                        return (part, "prefer")
                    }
                }
            }
        }
        // 3) 보조(읍/면/동) 직접 토큰 끝
        for t in tokens {
            if fallback.contains(where: { t.hasSuffix($0) }) {
                return (t, "fallback")
            }
        }
        // 4) 보조 내부 분리
        if let rg = try? NSRegularExpression(pattern: "(.*?(읍|면|동))(.*)") {
            for t in tokens {
                let ns = t as NSString
                let range = NSRange(location: 0, length: ns.length)
                if let m = rg.firstMatch(in: t, range: range),
                    m.numberOfRanges >= 2
                {
                    let part = ns.substring(with: m.range(at: 1))
                    return (part, "fallback")
                }
            }
        }
        return (nil, "")
    }

    var i = 0
    if provinceSuffixes.contains(where: { toks[0].hasSuffix($0) }) {
        i = 1
    }

    guard i < toks.count else {
        return nil
    }

    // 도시 탐색 (토큰 매칭 → 내부 분리 순)
    var cityIdx: Int? = nil
    var cityToken: String?
    var afterCityRemainderTokens: [String] = []

    for idx in i..<min(i + 3, toks.count) {
        if citySuffixes.contains(where: { toks[idx].hasSuffix($0) }) {
            cityIdx = idx
            cityToken = toks[idx]
            afterCityRemainderTokens = Array(toks.dropFirst(idx + 1))
            break
        }
    }
    if cityIdx == nil {
        for idx in i..<min(i + 3, toks.count) {
            if let (cityWithSuffix, rest) = splitCityInToken(toks[idx]) {
                cityIdx = idx
                cityToken = cityWithSuffix
                var tail: [String] = []
                if !rest.trimmingCharacters(in: .whitespaces).isEmpty {
                    tail.append(rest)
                }
                tail.append(contentsOf: toks.dropFirst(idx + 1))
                afterCityRemainderTokens = tail
                break
            }
        }
    }

    guard cityIdx != nil, let cityWithSuffix = cityToken else {
        return nil
    }

    // 구/군 우선, 없으면 읍/면/동
    let (unit, kind) = findAdminUnit(
        in: Array(afterCityRemainderTokens.prefix(4)),
        prefer: districtSuffixes,
        fallback: minorSuffixes
    )

    let cityBase = strip(cityWithSuffix, suffixes: citySuffixes)

    if let u = unit {
        return "\(cityBase) \(u)"
    } else {
        return cityBase
    }
}

private func shrinkKoreanTitle(_ s: String, limit: Int = 15) -> String {
    // 앞뒤 공백 제거
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

    // 불필요한 괄호/따옴표 등 제거
    let junkPairs: [Character] = [
        "\"", "“", "”", "'", "’", "‘", "(", ")", "[", "]", "{", "}", "…", "#",
    ]
    t.removeAll(where: { junkPairs.contains($0) })

    // 마침표/쉼표/물음표 등으로 너무 긴 문장은 첫 절만
    if let cut = t.firstIndex(where: { ".,!?;:·•".contains($0) }) {
        t = String(t[..<cut])
    }

    // 흔한 수식어 제거(짧게): "오늘의 ", "한가한 ", "작은 ", "조용한 " 등
    let commonPrefixes = [
        "오늘의 ", "오늘 ", "한가한 ", "조용한 ", "작은 ", "아주 ", "조금 ", "갑자기 ",
    ]
    for p in commonPrefixes {
        if t.hasPrefix(p) {
            t.removeFirst(p.count)
            break
        }
    }

    t = t.trimmingCharacters(in: .whitespacesAndNewlines)

    // 최종 길이 제한
    if t.count > limit {
        // 말 중간 끊김 최소화: 공백 기준으로 줄여보기
        let words = t.split(separator: " ").map(String.init)
        if words.count > 1 {
            var acc = ""
            for (idx, w) in words.enumerated() {
                let next = acc.isEmpty ? w : acc + " " + w
                if next.count <= limit {
                    acc = next
                } else {
                    // 단어 단위로 안 되면 마지막 단어를 잘라서 제한
                    if acc.isEmpty {
                        return String(w.prefix(limit))
                    } else {
                        return acc
                    }
                }
                if idx == words.count - 1 { return acc }
            }
            return acc.isEmpty ? String(t.prefix(limit)) : acc
        } else {
            return String(t.prefix(limit))
        }
    }
    return t
}
