//
//  PlayRecapCategoryIntent.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import AppIntents

struct PlayRecapCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "카테고리 전체 재생"
    static var description = IntentDescription("특정 추천 카테고리의 모든 로그를 재생합니다.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "카테고리 이름")
    var category: String

    // 기본 생성자
    init() {}

    init(category: String) {
        self.init()
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutBridge.shared.action = .playCategory(category)
        return .result()
    }
}
