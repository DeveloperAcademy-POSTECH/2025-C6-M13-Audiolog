//
//  ShortcutBridge.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import Foundation
import Observation

@Observable
final class ShortcutBridge {
    static let shared = ShortcutBridge()

    enum Action: Equatable {
        case none
        case startRecording
        case stopRecording
        case searchAndPlay(query: String)
        case playCategory(String)
    }

    var action: Action = .none
}
