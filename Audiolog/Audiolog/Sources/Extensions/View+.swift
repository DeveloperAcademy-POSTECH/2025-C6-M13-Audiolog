//
//  View+.swift
//  colight
//
//  Created by SeanCho on 6/14/25.
//

import SwiftUI

extension View {
    var screenWidth: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
            .bounds.width) ?? 0
    }

    var screenHeight: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
            .bounds.height) ?? 0
    }
}

extension View {
    func safeAreaInset(_ edge: Edge.Set) -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 0
        }
        let inset = window.safeAreaInsets
        switch edge {
        case .top: return inset.top
        case .bottom: return inset.bottom
        case .leading: return inset.left
        case .trailing: return inset.right
        default: return 0
        }
    }
}
