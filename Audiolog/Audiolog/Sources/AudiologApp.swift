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
    var body: some Scene {
        WindowGroup {
            AudiologView()
                .modelContainer(for: Recording.self)
        }
    }
}

let logger = LoggerWithTimestamp()
