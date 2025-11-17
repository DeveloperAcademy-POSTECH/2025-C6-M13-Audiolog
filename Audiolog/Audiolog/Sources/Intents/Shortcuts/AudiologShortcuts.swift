//
//  AudiologShortcuts.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import AppIntents

struct AudiologShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor = .navy

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "새 녹음 시작해 \(.applicationName)에서",
                "\(.applicationName)에서 새 녹음 시작"
            ],
            shortTitle: "새 녹음 시작",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: SearchAndPlayRecordingIntent(),
            phrases: [
                "\(.applicationName)에서 녹음 검색해줘",
                "\(.applicationName)에서 녹음 재생해줘",
                "\(.applicationName)에서 녹음 찾아줘"
            ],
            shortTitle: "녹음 검색·재생",
            systemImageName: "magnifyingglass.circle.fill"
        )
    }
}
