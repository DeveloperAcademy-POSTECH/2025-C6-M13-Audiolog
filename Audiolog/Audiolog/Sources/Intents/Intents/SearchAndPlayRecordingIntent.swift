//
//  SearchAndPlayRecordingIntent.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import AppIntents

struct SearchAndPlayRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "녹음 검색 후 재생"
    static var description = IntentDescription("입력한 검색어로 녹음을 찾고 재생합니다.")
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "검색어",
        description: "제목에 포함된 단어를 말하거나 입력해 주세요."
    )
    var query: String

    init() {}

    init(query: String) {
        self.init()
        self.query = query
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result() }

        ShortcutBridge.shared.action = .searchAndPlay(query: trimmed)
        return .result()
    }
}
