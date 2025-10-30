//
//  RecordView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import AVFoundation
import Combine
import SwiftUI
import SwiftData

struct RecordView: View {
    @State private var audioRecorder = AudioRecorder()
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) private var modelContext

    // 메인 UI 뷰
    var body: some View {
        VStack {
            if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                Text(
                    "You haven't authorized Spatial Audio Demo to use the microphone. Change these settings in Settings -> Privacy & Security."
                )
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .resizable()
                    .symbolRenderingMode(.multicolor)
                    .aspectRatio(contentMode: .fit)
            } else {
                if !audioRecorder.isRecording {
                    Text("Tap To Start Recording")
                        .font(
                            .system(size: 34, weight: .light, design: .default)
                        )
                }
                if audioRecorder.isRecording {
                    Text("Recording")
                    // 녹음 경과 시간을 표시하는 텍스트 라벨
                    Text(formatTime(audioRecorder.timeElapsed))
                        .font(
                            .system(
                                size: 32,
                                weight: .bold,
                                design: .monospaced
                            )
                        )
                    // 오디오 녹음을 위한 파형 UI
                    LiveWaveformShape(amplitudes: audioRecorder.amplitudes)
                        .stroke(Color.red, lineWidth: 2)
                        .background(Color.clear)
                        .frame(height: 200)
                        .animation(
                            .linear(duration: 0.05),
                            value: audioRecorder.amplitudes
                        )
                }
                VStack {
                    // 녹음 시작/정지 UI 버튼
                    Button {
                        if audioRecorder.isRecording {
                            Task {
                                await audioRecorder.stopRecording()
                                logger.log("[RecordView] Stopped recording. fileURL=\(String(describing: audioRecorder.fileURL)), elapsed=\(audioRecorder.timeElapsed))")
                                if let url = audioRecorder.fileURL {
                                    logger.log("[RecordView] Will insert Recording. url=\(url.absoluteString), duration=\(audioRecorder.timeElapsed))")
                                    let recording = Recording(fileURL: url, duration: audioRecorder.timeElapsed)
                                    modelContext.insert(recording)
                                    do {
                                        try modelContext.save()
                                        logger.log("[RecordView] Saved Recording to SwiftData. url=\(url.lastPathComponent), duration=\(recording.duration))")
                                    } catch {
                                        logger.log("[RecordView] ERROR: Failed to save Recording. error=\(String(describing: error))")
                                    }
                                } else {
                                    logger.log("[RecordView] ERROR: fileURL is nil after stopRecording(). Nothing was saved.")
                                }
                                audioRecorder.amplitudes.removeAll()
                            }
                        } else {
                            audioRecorder.amplitudes.removeAll()
                            logger.log("[RecordView] Starting recording...")
                            audioRecorder.startRecording()
                            logger.log("[RecordView] Recording started. isRecording=\(audioRecorder.isRecording))")
                        }
                    } label: {
                        Image(
                            systemName: audioRecorder.isRecording
                                ? "stop.fill" : "mic.fill"
                        )
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .padding()
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .padding()
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
        logger.log("[RecordView] Stopped recording due to scenePhase change to \(String(describing: scenePhase)). fileURL=\(String(describing: audioRecorder.fileURL)), elapsed=\(audioRecorder.timeElapsed))")
        if let url = audioRecorder.fileURL {
            logger.log("[RecordView] Will insert Recording (scenePhase). url=\(url.absoluteString), duration=\(audioRecorder.timeElapsed))")
            let recording = Recording(fileURL: url, duration: audioRecorder.timeElapsed)
            modelContext.insert(recording)
            do {
                try modelContext.save()
                logger.log("[RecordView] Saved Recording to SwiftData (scenePhase). url=\(url.lastPathComponent), duration=\(recording.duration))")
            } catch {
                logger.log("[RecordView] ERROR: Failed to save Recording on scenePhase change. error=\(String(describing: error))")
            }
        } else {
            logger.log("[RecordView] ERROR: fileURL is nil after stopRecording() on scenePhase change. Nothing was saved.")
        }
        audioRecorder.amplitudes.removeAll()
    }

    func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
