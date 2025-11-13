//
//  AudiologView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import SwiftData
import SwiftUI

struct AudiologView: View {
    @State private var audioPlayer = AudioPlayer()
    private let audioProcesser = AudioProcesser()
    
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var currentTab = "녹음"
    @State private var isPresentingPlayerSheet: Bool = false
    @State private var isReprocessingPending = false
    @State private var isRecordCreated: Bool = false
    @State private var isSelecting: Bool = false

    var body: some View {
        TabView(selection: $currentTab) {
            Tab(
                "녹음",
                systemImage: "microphone",
                value: "녹음"
            ) {
                RecordView(audioProcesser: audioProcesser, isRecordCreated: $isRecordCreated)
            }

            Tab(
                "전체 로그",
                systemImage: "play.square.stack.fill",
                value: "전체 로그"
            ) {
                ArchiveView(isRecordCreated: $isRecordCreated, isSelecting: $isSelecting)
            }
            .badge(isRecordCreated ? Text("N") : nil)

            Tab(
                "추천 로그",
                systemImage: "rectangle.split.2x2.fill",
                value: "추천 로그"
            ) {
                RecapView()
            }

            Tab(
                "검색",
                systemImage: "magnifyingglass",
                value: "검색",
                role: .search
            ) {
                SearchView()
            }
        }
        .overlay(alignment: .bottom) {
            if !isSelecting {
                VStack {
                    Spacer()
                    MiniPlayerView()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 58)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
        }
        .environment(audioPlayer)
        .task {
            let emptyThumb = UIImage()
            UISlider.appearance().setThumbImage(emptyThumb, for: .normal)
            await reprocessPendingTitlesIfNeeded()
        }
    }

    @MainActor
    private func reprocessPendingTitlesIfNeeded() async {
        guard !isReprocessingPending else { return }
        let targets = pendingRecordings()
        guard !targets.isEmpty else { return }

        isReprocessingPending = true
        defer { isReprocessingPending = false }

        logger.log(
            "[AudiologView] Reprocess pending titles. count=\(targets.count)"
        )

        let fileManager = FileManager.default
        let documentURL = getDocumentURL()

        for target in targets {
            let fileName = target.fileName
            let fileURL = documentURL.appendingPathComponent(fileName)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                logger.log(
                    "[AudiologView] Skip reprocess (file missing): \(fileURL)"
                )
                continue
            }
            let processor = AudioProcesser()
            await processor.enqueueProcess(for: target, modelContext: modelContext)
        }
        logger.log("[AudiologView] Reprocess done.")
    }

    private func pendingRecordings() -> [Recording] {
        recordings.filter { !$0.isTitleGenerated || $0.title.isEmpty }
    }
}
