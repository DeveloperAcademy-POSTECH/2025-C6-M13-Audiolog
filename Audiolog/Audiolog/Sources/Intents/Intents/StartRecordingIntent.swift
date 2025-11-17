//
//  StartRecordingIntent.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import AppIntents

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "새 녹음 시작"
    static var description = IntentDescription("Audiolog에서 새로운 녹음을 시작합니다.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutBridge.shared.action = .startRecording
        return .result()
    }
}
