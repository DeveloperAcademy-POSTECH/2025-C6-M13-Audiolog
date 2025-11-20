//
//  ContentView.swift
//  AudiologWatchRemote Watch App
//
//  Created by 성현 on 11/20/25.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var isRecordingRemote = false
    @State private var timelineStart: Date?
    @State private var timeElapsed: TimeInterval = 0

    @State private var isBusy: Bool = false
    @AccessibilityFocusState private var voFocused: Bool
    @State private var timer: Timer?

    @State private var titleText: String = "기억하고 싶은 소리를\n담아보세요"

    private var pulsingOpacity: Double {
        let t = timeElapsed
        return abs(sin(.pi * t / 3))
    }

    // 이걸 앱쪽 View+에 os로 분리할지, 여기서만 따로 쓸지는 고민해봐야할듯 합니당.
    private var screenWidth: CGFloat {
        WKInterfaceDevice.current().screenBounds.width
    }

    private var screenHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.height
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.main)
                .frame(width: 100, height: 100)
                .blur(radius: 60)
                .offset(x: 0, y: 0)

            TimelineView(
                .animation(
                    minimumInterval: 1.0 / 24.0
                )
            ) { context in
                let startWaveFrameCount = 90
                let repeatWaveFrameCount = 90
                let fps: Double = 24

                let baseline = timelineStart ?? context.date
                let t = context.date.timeIntervalSince(baseline)

                let frameName: String = {
                    let frameCount = Int(floor(t * fps))
                    if frameCount >= startWaveFrameCount {
                        return String(
                            format: "Record%03d",
                            (frameCount - startWaveFrameCount)
                                % repeatWaveFrameCount + startWaveFrameCount
                        )
                    } else {
                        return String(
                            format: "Record%03d",
                            frameCount
                        )
                    }
                }()

                if let uiImage = UIImage(named: frameName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenWidth, height: screenWidth)
                        .accessibilityHidden(true)
                } else {
                    EmptyView()
                        .frame(width: screenWidth, height: screenWidth)
                        .accessibilityHidden(true)
                }
            }
            .opacity(isRecordingRemote ? 1 : 0)
            .animation(
                .easeInOut(duration: 1),
                value: isRecordingRemote
            )

            VStack {
                Title3(text: titleText)
                    .opacity(isRecordingRemote ? 0 : 1)
                    .padding(.top, 30)
                    .accessibilityFocused($voFocused)
                Spacer()
            }
            .accessibilitySortPriority(1)

            VStack {
                HStack(spacing: 10) {
                    Circle().fill(.sub)
                        .frame(width: 8, height: 8)
                        .shadow(color: .sub, radius: 5)
                        .opacity(pulsingOpacity)

                    Text(formatTime(timeElapsed))
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.lbl1)
                        .monospacedDigit()
                }
                .padding(.top, screenHeight / 5)
                .opacity(isRecordingRemote ? 1 : 0)

                Spacer()
            }

            Button {
                guard !isBusy else { return }
                isBusy = true
                handleRemoteTap()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    isBusy = false
                }
            } label: {
                MicButtonLabel(isRecording: isRecordingRemote)
            }
        }
        .onAppear {
            if timelineStart == nil { timelineStart = Date() }
        }
    }

    private func handleRemoteTap() {
        if isRecordingRemote {
            stopLocalTimer()
            isRecordingRemote = false

            WatchWCSessionManager.shared.send(action: "stopRecording")

            titleText = "소리가 저장되었어요"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !isRecordingRemote {
                    titleText = "기억하고 싶은 소리를\n담아보세요"
                }
            }
        } else {
            timelineStart = Date()
            startLocalTimer()
            isRecordingRemote = true

            WatchWCSessionManager.shared.send(action: "startRecording")
        }
    }

    private func startLocalTimer() {
        timeElapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            _ in
            timeElapsed += 1
        }
    }

    private func stopLocalTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

#Preview {
    ContentView()
}
