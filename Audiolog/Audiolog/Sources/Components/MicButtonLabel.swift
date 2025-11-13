//
//  MicButtonLabel.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import CoreMotion
import SwiftUI

struct MicButtonLabel: View {
    private let motionManager = CMMotionManager()

    @State private var rotateAngle: Angle = Angle(radians: 0)

    let isRecording: Bool

    var body: some View {
        Image(systemName: isRecording ? "stop.fill" : "microphone.fill")
            .font(.system(size: isRecording ? 40 : 45))
            .tint(.white)
            .frame(width: 118, height: 118)
            .background(
                ZStack {
                    Circle().fill(.main.opacity(0.8))
                    Circle().fill(.ultraThinMaterial)
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(1),
                                    Color.white.opacity(0),
                                    Color.white.opacity(1),
                                    Color.white.opacity(0),
                                    Color.white.opacity(1),
                                ]),
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 0.4)
                        .padding(1)
                        .rotationEffect(rotateAngle)
                }
            )
            .glassEffect(.regular.interactive())
            .accessibilityLabel(isRecording ? "중단" : "녹음")
            .onAppear {
                startMotionUpdates()
            }
    }

    private func fetchDeviceOrientation() {
        if let gravity = motionManager.deviceMotion?.gravity {
            let x = gravity.x
            let y = gravity.y

            let newAngle = -Angle(radians: atan2(y, x))
            let current = rotateAngle.radians
            let target = newAngle.radians

            var delta = target - current
            while delta > .pi { delta -= 2 * .pi }
            while delta <= -.pi { delta += 2 * .pi }

            if abs(delta) > .pi {
                rotateAngle = newAngle
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    rotateAngle = newAngle
                }
            }
        }
    }

    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { _, _ in
            fetchDeviceOrientation()
        }
    }
}

#Preview {
    MicButtonLabel(isRecording: true)
}
