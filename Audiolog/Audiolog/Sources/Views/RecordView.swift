//
//  RecordView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import AVFoundation
import Combine
import SwiftData
import SwiftUI

struct RecordView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var audioRecorder = AudioRecorder()
    @State private var timelineStart: Date?

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) private var modelContext

    private let locationManager = LocationManager()
    private let weatherManager = WeatherManager()

    @State private var currentLocation: String?
    @State private var currentWeather: String?

    @State private var showToast: Bool = false
    @State private var isBusy: Bool = false
    @Binding var isRecordCreated: Bool
    @Binding var startFromShortcut: Bool

    @AccessibilityFocusState private var voFocused: Bool

    private var pulsingOpacity: Double {
        let t = audioRecorder.timeElapsed
        return abs(sin(.pi * t / 3))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 300, height: 300)
                    .cornerRadius(350)
                    .blur(radius: 160)
                    .offset(x: -100, y: -320)

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
                .opacity(audioRecorder.isRecording ? 1 : 0)
                .animation(
                    .easeInOut(duration: 1),
                    value: audioRecorder.isRecording
                )

                VStack {
                    Title3(
                        text: audioRecorder.isRecording
                            ? formattedDateString(
                                fromPTS: audioRecorder.firstBufferPTS
                            )
                            : String(localized: "기억하고 싶은 소리를\n담아보세요")
                    )
                    .opacity(audioRecorder.isRecording ? 0 : 1)
                    .padding(.top, 30)
                    .accessibilityFocused($voFocused)
                    Spacer()
                }

                VStack {
                    HStack(spacing: 10) {
                        Circle().fill(.sub)
                            .frame(width: 8, height: 8)
                            .shadow(color: .sub, radius: 5)
                            .opacity(pulsingOpacity)

                        Text(formatTime(audioRecorder.timeElapsed))
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.lbl1)
                            .monospacedDigit()
                    }
                    .padding(.top, screenHeight / 5)
                    .opacity(audioRecorder.isRecording ? 1 : 0)
                    .accessibilityHidden(true)

                    Spacer()
                }

                Toast()
                    .opacity(showToast ? 1 : 0)
                    .offset(y: -112)

                Button {
                    guard !isBusy else { return }
                    isBusy = true
                    handleRecordButtonTapped()
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        isBusy = false
                    }
                } label: {
                    MicButtonLabel(isRecording: audioRecorder.isRecording)
                }
            }
            .overlay(alignment: .bottom) {
                VStack {
                    Spacer()
                    MiniPlayerView()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
            .background(.bg1)
            .onAppear {
                if timelineStart == nil { timelineStart = Date() }
                locationManager.onLocationUpdate = { location, address in
                    logger.log("location 업데이트 됨")
                    self.currentLocation = address
                    Task {
                        self.currentWeather =
                            try await weatherManager.getWeather(
                                location: location
                            )
                        logger.log("currentWeather: \(currentWeather ?? "")")
                    }
                }
                audioRecorder.setupCaptureSession()
                locationManager.requestLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    voFocused = true
                }
            }
            .onDisappear {
                if audioRecorder.isRecording {
                    Task {
                        await stopRecording()
                    }
                }
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: scenePhase) {
                guard audioRecorder.isRecording,
                    scenePhase == .background || scenePhase == .inactive
                else { return }
                Task {
                    await stopRecording()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoteStopRecording)) { _ in
                if audioRecorder.isRecording {
                    Task { await stopRecording() }
                }
            }
        }
        .accessibilityAction(.magicTap) {
            handleRecordButtonTapped()
        }
        .task(id: startFromShortcut) {
            guard startFromShortcut else { return }

            if !audioRecorder.isRecording {
                startRecording()
            }

            startFromShortcut = false
        }
    }

    private func handleRecordButtonTapped() {
        if audioRecorder.isRecording {
            Task { await stopRecording() }
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        logger.log("[RecordView] Starting recording...")

        if audioPlayer.isPlaying {
            audioPlayer.pause()
        }

        timelineStart = Date()
        audioRecorder.startRecording()
        UIApplication.shared.isIdleTimerDisabled = true

        logger.log(
            "[RecordView] Recording started. isRecording=\(audioRecorder.isRecording))"
        )
    }

    private func stopRecording() async {
        let fileName = audioRecorder.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        await audioRecorder.stopRecording()
        logger.log(
            "[RecordView] Stopped recording. fileURL=\(String(describing: fileURL)), elapsed=\(audioRecorder.timeElapsed))"
        )

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                showToast = true
            }
        }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showToast = false
                }
            }
        }

        logger.log(
            "[RecordView] Will insert Recording. url=\(fileURL.absoluteString), duration=\(audioRecorder.timeElapsed))"
        )

        locationManager.requestLocation()

        let recording = Recording(
            fileName: fileName,
            duration: audioRecorder.timeElapsed,
            weather: currentWeather,
            location: currentLocation
        )
        modelContext.insert(recording)

        do {
            try modelContext.save()
            await MainActor.run { isRecordCreated = true }
            logger.log(
                "[RecordView] Saved Recording to SwiftData. url=\(fileURL.lastPathComponent), duration=\(recording.duration))"
            )
        } catch {
            logger.log(
                "[RecordView] ERROR: Failed to save Recording. error=\(String(describing: error))"
            )
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }

    private func formattedDateString(fromPTS pts: CMTime?) -> String {
        let date: Date
        if let pts = pts, pts.isNumeric, pts.seconds.isFinite {
            date = Date()
        } else {
            date = Date()
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM월 dd일 HH시 mm분"
        return formatter.string(from: date)
    }
}
