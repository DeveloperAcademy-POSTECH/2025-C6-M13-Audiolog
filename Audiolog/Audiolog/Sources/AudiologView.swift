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

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var currentTab = "Archive" //TODO: 원상복구
    @State private var isPresentingPlayerSheet: Bool = false
    @State private var isReprocessingPending = false
    @State private var isRecordCreated: Bool = false

    var body: some View {
        TabView(selection: $currentTab) {
            Tab(
                "Record",
                systemImage: "microphone",
                value: "Record"
            ) {
                RecordView(isRecordCreated: $isRecordCreated)
            }

            Tab(
                "Archive",
                systemImage: "rectangle.split.2x2.fill",
                value: "Archive"
            ) {
                ArchiveView(isRecordCreated: $isRecordCreated)
            }
            .badge(isRecordCreated ? Text("N") : nil)

            Tab(
                "Recap",
                systemImage: "star.fill",
                value: "Recap"
            ) {
                RecapView()
            }

            Tab(
                "Search",
                systemImage: "magnifyingglass",
                value: "Search",
                role: .search
            ) {
                SearchView()
            }
        }
        .overlay {
            VStack {
                Spacer()
                MiniPlayerView()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 58)
            .padding(.horizontal, 20)
        }
        .environment(audioPlayer)
        .task {
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
            await processor.processAudio(for: target, modelContext: modelContext)
        }
        logger.log("[AudiologView] Reprocess done.")
    }

    private func pendingRecordings() -> [Recording] {
        recordings.filter { !$0.isTitleGenerated || $0.title.isEmpty }
    }
}
