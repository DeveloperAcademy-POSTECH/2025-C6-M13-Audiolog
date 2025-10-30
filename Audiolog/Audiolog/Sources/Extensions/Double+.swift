//
//  Double+.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import Foundation

extension Double {
    var formattedTime: String {
        guard self.isFinite && self >= 0 else { return "0:00" }
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
