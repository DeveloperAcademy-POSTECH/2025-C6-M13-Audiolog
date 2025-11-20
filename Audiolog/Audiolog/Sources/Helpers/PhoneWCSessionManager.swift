//
//  PhoneWCSessionManager.swift
//  Audiolog
//
//  Created by 성현 on 11/20/25.
//

import Foundation
import WatchConnectivity

final class PhoneWCSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneWCSessionManager()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any]
    ) {
        guard let action = message["action"] as? String else { return }

        DispatchQueue.main.async {
            switch action {
            case "startRecording":
                ShortcutBridge.shared.action = .startRecording
                
            case "stopRecording":
                ShortcutBridge.shared.action = .stopRecording

            default:
                break
            }
        }
    }
}
