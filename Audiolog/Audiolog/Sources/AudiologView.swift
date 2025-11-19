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
    @State private var audioProcesser = AudioProcesser()

    @State private var generateTitleTask: Task<Void, Never>?

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var currentTab = "녹음"
    @State private var isPresentingPlayerSheet: Bool = false
    @State private var isReprocessingPending = false
    @State private var isRecordCreated: Bool = false

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
                    isRecordCreated: $isRecordCreated
                )
            }
            .badge(isRecordCreated ? Text("N") : nil)

            Tab(
                "추천 로그",
                systemImage: "rectangle.grid.2x2.fill",
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
        .environment(audioPlayer)
        .task {
            let emptyThumb = UIImage()
            UISlider.appearance().setThumbImage(emptyThumb, for: .normal)
            handlePendingRecordings()
        }
        .onChange(of: shortcutBridge.action) { _, newValue in
            handleShortcutAction(newValue)
        }
        .onChange(of: processedCount) {
            updateRecapWidgetSnapshot()
        }
        .onChange(of: recordings) {
            logger.log("recordings changed")
            handlePendingRecordings()
        }
        .onAppear {
            updateRecapWidgetSnapshot()
        }
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

    private func handlePendingRecordings() {
        generateTitleTask?.cancel()
        generateTitleTask = Task {
            let pending = recordings.filter { recording in
                recording.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
                    || recording.isTitleGenerated == false
            }

            if pending.isEmpty {
                logger.log("[AudiologView] 제목 미생성 레코딩 없음")
            } else {
                logger.log("[AudiologView] 제목 미생성 레코딩 \(pending.count)개 발견")

                for recording in pending {
                    if Task.isCancelled { break }
                    await audioProcesser.configureLanguageModelSession()
                    await audioProcesser.classify(recording: recording)
                    await audioProcesser.transcribe(recording: recording)
                    await audioProcesser.shazam(recording: recording)
                    await audioProcesser.generateTitle(recording: recording)

                    try? modelContext.save()
                    logger.log(
                        "[RecordView] Title generated and saved. title: \(recording.title)"
                    )
                }
            }

            if !Task.isCancelled { generateTitleTask = nil }
        }
    }
}
