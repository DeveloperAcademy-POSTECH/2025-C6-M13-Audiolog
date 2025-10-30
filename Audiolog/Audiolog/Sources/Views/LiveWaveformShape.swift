//
//  LiveWaveformShape.swift
//  Audiolog
//
//  Created by Assistant on 10/28/25.
//

import SwiftUI

struct LiveWaveformShape: Shape {
    var amplitudes: [Float]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.height / 2
        let widthPerSample = rect.width / CGFloat(amplitudes.count)

        for (index, amp) in amplitudes.enumerated() {
            let xValue = CGFloat(index) * widthPerSample
            let height = CGFloat(amp) * rect.height / 2
            path.move(to: CGPoint(x: xValue, y: midY - height))
            path.addLine(to: CGPoint(x: xValue, y: midY + height))
        }

        return path
    }
}
