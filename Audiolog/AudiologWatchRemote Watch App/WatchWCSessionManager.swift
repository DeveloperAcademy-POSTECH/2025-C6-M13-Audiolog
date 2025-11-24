//
//  WatchWCSessionManager.swift
//  AudiologWatchRemote Watch App
//
//  Created by 성현 on 11/20/25.
//

import Foundation
import WatchConnectivity

final class WatchWCSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchWCSessionManager()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(action: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["action": action],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: - WCSessionDelegate (워치 쪽은 거의 비워도 됨)

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionReachabilityDidChange(_ session: WCSession) {
        // 필요하면 reachable 여부 보고 UI 갱신 가능
    }
}
