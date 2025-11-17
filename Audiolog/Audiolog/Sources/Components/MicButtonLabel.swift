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
            .font(.system(size: 44))
            .tint(.white.opacity(0.9))
            .frame(width: 96, height: 96)
            .background(
                ZStack {
                    Circle().fill(.main.opacity(0.5))
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(1),
                                    Color.sub.opacity(0.4),
                                    Color.main.opacity(0.4),
                                    Color.white.opacity(1),
                                    Color.sub.opacity(0.4),
                                    Color.main.opacity(0.4),
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
            .glassEffect(.clear)
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
            rotateAngle = newAngle
        }
    }

    private func startMotionUpdates() {
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(to: .main) { _, _ in
            fetchDeviceOrientation()
        }
    }
}
