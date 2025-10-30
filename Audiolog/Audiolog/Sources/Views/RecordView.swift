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
    @State private var audioRecorder = AudioRecorder()
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var showToast: Bool = false

    var body: some View {
        ZStack {
            if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                Text(
                    "You haven't authorized Spatial Audio Demo to use the microphone. Change these settings in Settings -> Privacy & Security."
                )
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .resizable()
                    .symbolRenderingMode(.multicolor)
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack {
                    Title(
                        text: audioRecorder.isRecording
                            ? formattedDateString(
                                fromPTS: audioRecorder.firstBufferPTS
                            )
                            : "오늘의 로그를 남겨볼까요?"
                    )
                    .padding(.top, 44)
                    Spacer()
                }

                if audioRecorder.isRecording {
                    Text(formatTime(audioRecorder.timeElapsed))
                        .font(.body)
                        .offset(y: -90)
                }

                Toast()
                    .opacity(showToast ? 1 : 0)
                    .offset(y: -98)

                Button {
                    handleRecordButtonTapped()
                } label: {
                    MicButtonLabel(isRecording: audioRecorder.isRecording)
                }
            }
        }
        .onAppear {
            audioRecorder.setupCaptureSession()
        }
        .onDisappear {
            if audioRecorder.isRecording {
                Task {
                    await stopAndPersistRecordingOnScenePhaseChange()
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background || scenePhase == .inactive {
                if audioRecorder.isRecording {
                    Task {
                        await stopAndPersistRecordingOnScenePhaseChange()
                    }
                }
            }
        }
    }

    private func stopAndPersistRecordingOnScenePhaseChange() async {
        await audioRecorder.stopRecording()
        logger.log(
            "[RecordView] Stopped recording due to scenePhase change to \(String(describing: scenePhase)). fileURL=\(String(describing: audioRecorder.fileURL)), elapsed=\(audioRecorder.timeElapsed))"
        )
        if let url = audioRecorder.fileURL {
            logger.log(
                "[RecordView] Will insert Recording (scenePhase). url=\(url.absoluteString), duration=\(audioRecorder.timeElapsed))"
            )
            let recording = Recording(
                fileURL: url,
                duration: audioRecorder.timeElapsed
            )
            modelContext.insert(recording)
            do {
                try modelContext.save()
                logger.log(
                    "[RecordView] Saved Recording to SwiftData (scenePhase). url=\(url.lastPathComponent), duration=\(recording.duration))"
                )
            } catch {
                logger.log(
                    "[RecordView] ERROR: Failed to save Recording on scenePhase change. error=\(String(describing: error))"
                )
            }
        } else {
            logger.log(
                "[RecordView] ERROR: fileURL is nil after stopRecording() on scenePhase change. Nothing was saved."
            )
        }
    }

    private func handleRecordButtonTapped() {
        if audioRecorder.isRecording {
            Task {
                await audioRecorder.stopRecording()
                logger.log(
                    "[RecordView] Stopped recording. fileURL=\(String(describing: audioRecorder.fileURL)), elapsed=\(audioRecorder.timeElapsed))"
                )
                // showToast 2초간 true 후 false
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

                if let url = audioRecorder.fileURL {
                    logger.log(
                        "[RecordView] Will insert Recording. url=\(url.absoluteString), duration=\(audioRecorder.timeElapsed))"
                    )
                    let recording = Recording(
                        fileURL: url,
                        duration: audioRecorder.timeElapsed
                    )
                    modelContext.insert(recording)
                    do {
                        try modelContext.save()
                        logger.log(
                            "[RecordView] Saved Recording to SwiftData. url=\(url.lastPathComponent), duration=\(recording.duration))"
                        )
                    } catch {
                        logger.log(
                            "[RecordView] ERROR: Failed to save Recording. error=\(String(describing: error))"
                        )
                    }
                } else {
                    logger.log(
                        "[RecordView] ERROR: fileURL is nil after stopRecording(). Nothing was saved."
                    )
                }
            }
        } else {
            logger.log("[RecordView] Starting recording...")
            audioRecorder.startRecording()
            logger.log(
                "[RecordView] Recording started. isRecording=\(audioRecorder.isRecording))"
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
