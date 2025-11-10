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

    // TODO: Weather, Location 관련 Manager 모셔오기
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) private var modelContext

    @State private var showToast: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 400, height: 400)
                    .cornerRadius(350)
                    .blur(radius: 100)
                    .offset(x: -100, y: -320)

                VStack {
                    Title3(
                        text: audioRecorder.isRecording
                            ? formattedDateString(
                                fromPTS: audioRecorder.firstBufferPTS
                            )
                            : "기억하고 싶은 소리를\n담아보세요"
                    )
                    .padding(.top, 30)
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

                Circle()
                    .fill(.main)
                    .frame(width: 100, height: 100)
                    .blur(radius: 44)
                    .offset(x: 0, y: 0)

                Button {
                    handleRecordButtonTapped()
                } label: {
                    MicButtonLabel(isRecording: audioRecorder.isRecording)
                }
                .offset(x: 0, y: 0)
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
                guard audioRecorder.isRecording,
                    scenePhase == .background || scenePhase == .inactive
                else { return }
                Task {
                    await stopAndPersistRecordingOnScenePhaseChange()
                }
            }
        }
    }

    private func stopAndPersistRecordingOnScenePhaseChange() async {
        await audioRecorder.stopRecording()
        logger.log(
            "[RecordView] Stopped recording due to scenePhase=\(String(describing: scenePhase)). "
                + "fileURL=\(String(describing: audioRecorder.fileURL)), elapsed=\(audioRecorder.timeElapsed)"
        )

        guard let url = audioRecorder.fileURL else {
            logger.log(
                "[RecordView] ERROR: fileURL is nil after stopRecording() on scenePhase change. Nothing was saved."
            )
            return
        }

        let recording = Recording(
            fileURL: url,
            title: "",
            isTitleGenerated: false,
            duration: audioRecorder.timeElapsed
        )
        modelContext.insert(recording)
        do {
            try modelContext.save()
            logger.log(
                "[RecordView] Saved Recording to SwiftData (scenePhase). url=\(url.lastPathComponent), duration=\(recording.duration)"
            )
        } catch {
            logger.log(
                "[RecordView] ERROR: Failed to save Recording on scenePhase change. error=\(String(describing: error))"
            )
            return
        }

        do {
            _ = try await waitUntilFileReady(url)
        } catch {
            let ns = error as NSError
            logger.log(
                "[RecordView] waitUntilFileReady FAIL: \(ns.domain)(\(ns.code)) \(ns.localizedDescription)"
            )
        }

        let processor = AudioProcesser()  // DI 사용 시 주입 인스턴스로 교체
        await processor.processAudio(for: recording, modelContext: modelContext)
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

                    // TODO: Location, Weather 넣기
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

                        // 엘리안 슈퍼 분석 세트 돌리기
                        do {
                            _ = try await waitUntilFileReady(url)
                        } catch {
                            let ns = error as NSError
                            logger.log(
                                "[RecordView] waitUntilFileReady FAIL: \(ns.domain)(\(ns.code)) \(ns.localizedDescription)"
                            )
                        }

                        let processor = AudioProcesser()
                        await processor.processAudio(
                            for: recording,
                            modelContext: modelContext
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

    private func waitUntilFileReady(
        _ url: URL,
        stableWindowMs: Int = 300,  // 사이즈가 이 시간만큼 변하지 않으면 "안정"
        timeout: TimeInterval = 5.0,  // 최대 대기 시간
        pollIntervalMs: Int = 100  // 폴링 주기
    ) async throws -> URL {
        let fm = FileManager.default
        let start = Date()
        var lastSize: UInt64 = 0
        var lastChange = Date()

        func currentSize() -> UInt64 {
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                let n = attrs[.size] as? NSNumber
            else { return 0 }
            return n.uint64Value
        }

        while true {
            let now = Date()

            if now.timeIntervalSince(start) >= timeout {
                throw APFailure(
                    "타임아웃: 파일이 준비되지 않았습니다 (\(url.lastPathComponent))"
                )
            }

            guard fm.fileExists(atPath: url.path) else {
                try? await Task.sleep(
                    nanoseconds: UInt64(pollIntervalMs) * 1_000_000
                )
                continue
            }

            let size = currentSize()
            if size != lastSize {
                lastSize = size
                lastChange = now
            }

            let stableForMs = now.timeIntervalSince(lastChange) * 1000
            let stableEnough = stableForMs >= Double(stableWindowMs)

            if stableEnough && size > 0 {
                let asset = AVURLAsset(url: url)
                do {
                    let tracks = try await asset.load(.tracks)
                    let hasAudio = tracks.contains { $0.mediaType == .audio }
                    if hasAudio {
                        logger.log(
                            "[waitUntilFileReady] ready url=\(url.lastPathComponent) size=\(size)B"
                        )
                        return url
                    } else {
                        logger.log(
                            "[waitUntilFileReady] no audio tracks yet. size=\(size)B"
                        )
                    }
                } catch {
                    let ns = error as NSError
                    logger.log(
                        "[waitUntilFileReady] asset.load(.tracks) error \(ns.domain)(\(ns.code)): \(ns.localizedDescription)"
                    )
                }
            }

            try? await Task.sleep(
                nanoseconds: UInt64(pollIntervalMs) * 1_000_000
            )
        }

        throw APFailure("타임아웃: 파일이 준비되지 않았습니다 (\(url.lastPathComponent))")
    }
}
