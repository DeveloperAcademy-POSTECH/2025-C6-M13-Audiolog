//
//  AudiologWatchRemoteApp.swift
//  AudiologWatchRemote Watch App
//
//  Created by 성현 on 11/20/25.
//

import SwiftUI
import WatchConnectivity

@main
struct AudiologWatchRemoteApp: App {
    init() {
        WatchWCSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
