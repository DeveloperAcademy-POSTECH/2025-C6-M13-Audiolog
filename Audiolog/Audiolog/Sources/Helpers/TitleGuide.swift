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
        tagWeights: [String: Int]? = nil
    ) async -> String? {

        let ctxObj = TitleContext(recording: recording, weights: tagWeights)
        let ctxJSON = ctxObj.toJSON()

        // 태그 비율이 너무 애매하면 일단 실패 처리
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
        let N = 3
        let opts = GenerationOptions(temperature: temperature)

        for _ in 0..<N {
            do {
                let res = try await session.respond(options: opts) {
                    Prompt(prompt)
                }
                let raw = res.content.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !raw.isEmpty else { continue }

                let firstLine = raw.components(separatedBy: .newlines).first ?? raw

                let allowLongMusic = allowsLongMusicTitle(
                    raw: firstLine,
                    recording: recording,
                    ctx: ctxObj
                )
                let short = allowLongMusic
                    ? shrinkKoreanTitle(firstLine, limit: 64)
                    : shrinkKoreanTitle(firstLine, limit: 22)

                if !short.isEmpty {
                    candidates.append(short)
                }
            } catch {
                continue
            }
        }

        guard !candidates.isEmpty else { return nil }

        let filtered = candidates.filter { !isIncompatible(title: $0, ctx: ctxObj) }
        var best = (filtered.first ?? candidates.first)!

        if
            let loc = formatKoreanLocationSuffix(from: recording.location),
            !loc.isEmpty,
            !best.contains(loc)
        {
            best += ", \(loc)"
        }

        return best
    }
}

// MARK: - 하드 불일치 필터

private func isIncompatible(title t: String, ctx: TitleContext) -> Bool {
    if !ctx.hasVoice &&
        (t.contains("대화")
         || t.contains("회의")
         || t.contains("인터뷰")
         || t.contains("혼잣말"))
    {
        return true
    }
    if !ctx.hasWaterAllowed &&
        (t.contains("파도") || t.contains("바다") || t.contains("해변"))
    {
        return true
    }
    if !ctx.hasWalkingCues &&
        (t.contains("산책")
         || t.contains("걷")
         || t.contains("발걸음")
         || t.contains("조깅"))
    {
        return true
    }

    return false
}

private func allowsLongMusicTitle(
    raw: String,
    recording: Recording,
    ctx: TitleContext
) -> Bool {
    let primary = ctx.primaryTag?.lowercased() ?? ""
    let musicy = [
        "music", "singing", "instrument", "song", "guitar", "piano",
        "keyboard", "drum",
    ]
    .contains { primary.contains($0) }

    let title = (recording.bgmTitle ?? "").trimmingCharacters(in: .whitespaces)
    let artist = (recording.bgmArtist ?? "").trimmingCharacters(
        in: .whitespaces
    )

    let looksLikeMetaSeparator =
        raw.contains(",") || raw.contains(" - ") || raw.contains("—")

    let containsMeta =
        (!title.isEmpty && raw.contains(title))
        || (!artist.isEmpty && raw.contains(artist))

    return musicy && (containsMeta || looksLikeMetaSeparator)
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
        // hasWalkingCues는 이번 턴 전용 힌트로만 쓰고, JSON에는 굳이 안 넣어도 됨
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
        hasWaterAllowed = ratio(for: ["waves", "wave", "water", "ocean", "sea"]) >= 0.15
        hasWalkingCues = ratio(for: ["footsteps", "walking", "walk", "jog", "stroll"]) >= 0.15
    }

    func toJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        return (try? String(data: enc.encode(self), encoding: .utf8)) ?? "{}"
    }
}

// MARK: - Prompt Builder (Lite)

private func buildUserPrompt(
    contextJSON: String,
    hasWalkingCues: Bool,
    primaryTag: String
) -> String {

    let walkHint = hasWalkingCues
        ? "- 걷는 소리가 충분해서 '산책/걷기/조깅' 같은 표현을 써도 됩니다."
        : "- 걷는 소리가 거의 없으니 '산책/걷기/조깅' 같은 표현은 쓰지 마세요."

    let speechHint =
        primaryTag.lowercased().contains("speech")
        ? "- 주태그가 speech라면, 대화/회의/인터뷰처럼 말소리를 중심으로 표현해 주세요."
        : ""

    return """
    너에게 이번 녹음에 대한 정보가 JSON 형식으로 주어진다.

    제목 작성 지침:
    - 자연스럽고 간결한 한국어 한 문장 제목을 한 줄만 작성한다.
    - 줄바꿈, 따옴표, 이모지, 해시태그, 접두 라벨을 쓰지 않는다.
    - JSON에 없는 사람 이름/장소/곡명/행사 이름은 새로 만들지 않는다.

    추가 힌트:
    \(walkHint)
    \(speechHint)

    아래는 이번 녹음의 세부 정보(JSON)이다. 내용을 참고만 하고, JSON 자체를 반복해서 출력하지 마라.

    CONTEXT_JSON_START
    \(contextJSON)
    CONTEXT_JSON_END

    위 정보를 바탕으로 제목 한 문장을 출력해라.
    """
}

// MARK: - Location suffix

private func formatKoreanLocationSuffix(from location: String?) -> String? {
    guard let raw = location?.trimmingCharacters(in: .whitespacesAndNewlines),
        !raw.isEmpty
    else {
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
    let (unit, _) = findAdminUnit(
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

// MARK: - Title shrinker

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
