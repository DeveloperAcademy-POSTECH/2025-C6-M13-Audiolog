//
//  ContentView.swift
//  AudiologWatchRemote Watch App
//
//  Created by 성현 on 11/20/25.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    // 녹음 단계
    private enum RecordingPhase {
        case idle        // 녹음 전 (기본 상태)
        case recording   // 녹음 중
        case finished    // 방금 저장 완료
    }

    @State private var isRecordingRemote = false
    @State private var timelineStart: Date?
    @State private var timeElapsed: TimeInterval = 0

    @State private var isBusy: Bool = false
    @AccessibilityFocusState private var voFocused: Bool
    @State private var timer: Timer?

    @State private var phase: RecordingPhase = .idle

    private var pulsingOpacity: Double {
        let t = timeElapsed
        return abs(sin(.pi * t / 3))
    }

    private var screenWidth: CGFloat {
        WKInterfaceDevice.current().screenBounds.width
    }

    private var screenHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.height
    }

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .center, spacing: 10) {
                    switch phase {
                    case .idle:
                        Text("기억하고 싶은 소리를\n담아보세요")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)

                    case .recording:
                        Circle()
                            .fill(.sub)
                            .frame(width: 8, height: 8)
                            .shadow(color: .sub, radius: 5)
                            .opacity(pulsingOpacity)

                        Text(formatTime(timeElapsed))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                    case .finished:
                        Text("소리가 저장되었어요")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity,
                       alignment: phase == .recording ? .bottom : .leading)
                .accessibilityFocused($voFocused)

                Spacer()
            }

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
                                        % repeatWaveFrameCount
                                        + startWaveFrameCount
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
                    .buttonStyle(.plain)
                }
        }
        .onAppear {
            if timelineStart == nil { timelineStart = Date() }
        }
    }

    // MARK: - Actions

    private func handleRemoteTap() {
        if isRecordingRemote {
            stopLocalTimer()
            isRecordingRemote = false

            WatchWCSessionManager.shared.send(action: "stopRecording")

            phase = .finished

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !isRecordingRemote {
                    phase = .idle
                }
            }
        } else {
            timelineStart = Date()
            startLocalTimer()
            isRecordingRemote = true

            phase = .recording

            WatchWCSessionManager.shared.send(action: "startRecording")
        }
    }

    // MARK: - Timer

    private func startLocalTimer() {
        timeElapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
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
