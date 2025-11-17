//
//  AudiologApp.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import SwiftUI
import SwiftData

@main
struct AudiologApp: App {
    @State private var shortcutBridge = ShortcutBridge()
    
    var body: some Scene {
        WindowGroup {
            AudiologView()
                .environment(shortcutBridge)
                .modelContainer(for: Recording.self)
        }
    }
}

let logger = LoggerWithTimestamp()
