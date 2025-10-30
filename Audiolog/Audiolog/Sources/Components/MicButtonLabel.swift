//
//  MicButtonLabel.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct MicButtonLabel: View {
    let isRecording: Bool

    var body: some View {
        Image(systemName: isRecording ? "stop.fill" : "microphone.fill")
            .font(.system(size: isRecording ? 40 : 45))
            .tint(.primary)
            .frame(width: 118, height: 118)
            .glassEffect()
    }
}

#Preview {
    MicButtonLabel(isRecording: true)
}
