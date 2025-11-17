//
//  AudiologView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/27/25.
//

import SwiftData
import SwiftUI
import WidgetKit

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

    @State private var shortcutBridge = ShortcutBridge.shared
    @State private var startRecordingFromShortcut: Bool = false
    @State private var searchQueryFromShortcut: String = ""

    private var processedCount: Int {
        recordings.filter { $0.isTitleGenerated }.count
    }

    var body: some View {
        TabView(selection: $currentTab) {
            Tab(
                "녹음",
                systemImage: "microphone",
                value: "녹음"
            ) {
                RecordView(
                    audioProcesser: audioProcesser,
                    isRecordCreated: $isRecordCreated,
                    startFromShortcut: $startRecordingFromShortcut
                )
            }

            Tab(
                "전체 로그",
                systemImage: "play.square.stack.fill",
                value: "전체 로그"
            ) {
                ArchiveView(
                    isRecordCreated: $isRecordCreated,
                    isSelecting: $isSelecting
                )
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
                SearchView(
                    externalQuery: $searchQueryFromShortcut
                )
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
            await reprocessPendingTitlesIfNeeded()
        }
        .onChange(of: shortcutBridge.action) { _, newValue in
            handleShortcutAction(newValue)
        }
        .onChange(of: processedCount) { _ in
            updateRecapWidgetSnapshot()
        }
        .onAppear {
            updateRecapWidgetSnapshot()
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
            await processor.enqueueProcess(
                for: target,
                modelContext: modelContext
            )
        }
        logger.log("[AudiologView] Reprocess done.")
    }

    private func pendingRecordings() -> [Recording] {
        recordings.filter { !$0.isTitleGenerated || $0.title.isEmpty }
    }

    private func handleShortcutAction(_ action: ShortcutBridge.Action) {
        switch action {
        case .none:
            break

        case .startRecording:
            currentTab = "녹음"
            startRecordingFromShortcut = true

        case .searchAndPlay(let query):
            currentTab = "검색"
            searchQueryFromShortcut = query

        case .playCategory(let tag):
            currentTab = "추천 로그"
            playCategory(tag)
        }

        shortcutBridge.action = .none
    }

    private func updateRecapWidgetSnapshot() {
        let favoriteCount = recordings.filter { $0.isFavorite }.count

        var tagToRecordingIDs: [String: Set<ObjectIdentifier>] = [:]
        for recording in recordings {
            let uniqueTags = Set(recording.tags ?? [])
            let id = ObjectIdentifier(recording as AnyObject)
            for tag in uniqueTags {
                tagToRecordingIDs[tag, default: []].insert(id)
            }
        }

        var dict: [String: Int] = [:]

        if favoriteCount > 0 {
            dict["즐겨찾기"] = favoriteCount
        }

        for (tag, ids) in tagToRecordingIDs where ids.count >= 3 {
            dict[tag] = ids.count
        }

        let defaults = UserDefaults(suiteName: "group.seancho.audiolog")
        defaults?.set(dict, forKey: "recap_items_dict")

        WidgetCenter.shared.reloadTimelines(ofKind: "StartRecordingWidget")

        logger.log("[AudiologView] Updated recap widget snapshot. dict=\(dict)")
    }

    private func playCategory(_ tag: String) {
        let filtered = recordings.filter { recording in
            if tag == "즐겨찾기" {
                return recording.isFavorite
            }
            return (recording.tags ?? []).contains(tag)
        }

        guard !filtered.isEmpty else {
            logger.log("[AudiologView] playCategory(\(tag)) – empty")
            return
        }

        audioPlayer.setPlaylist(filtered)
        audioPlayer.load(filtered[0])
        audioPlayer.play()

        logger.log("[AudiologView] playCategory(\(tag)) – started")
    }

}
