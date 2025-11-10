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
            .tint(.white)
            .frame(width: 118, height: 118)
            .background(
                ZStack {
                    Circle().fill(.main)
                    Circle().fill(.ultraThinMaterial)
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(1),
                                    Color.white.opacity(1),
                                    Color.white.opacity(1),
                                    Color.white.opacity(0),
                                    Color.white.opacity(0),
                                    Color.white.opacity(1),
                                    Color.white.opacity(1),
                                    Color.white.opacity(1),
                                    Color.white.opacity(0),
                                    Color.white.opacity(0),
                                    Color.white.opacity(1),
                                ]),
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .blur(radius: 0.6)
                        .opacity(0.8)
                        .padding(1)
                }
            )
            .glassEffect(.regular.interactive())
    }
}

#Preview {
    MicButtonLabel(isRecording: true)
}
