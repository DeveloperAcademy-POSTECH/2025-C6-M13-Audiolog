//
//  SearchView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import FoundationModels
import SwiftData
import SwiftUI

private enum RecentSearch {
    static let data = "RecentSearch"
}

struct SearchView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var recordingSearcher = RecordingSearcher()

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var searchText: String = ""
    @State private var searchedText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var searchingWithAI: Bool = false
    @State private var searchingIndex: Int = 0
    @State private var searchTask: Task<Void, Never>?

    @Binding var externalQuery: String
    @Binding var isIntelligenceEnabled: Bool
    @State private var isPresenting = false

    @AppStorage(RecentSearch.data) private var recentSearch: String = ""

    private var navTitle: String {
        if searchText.isEmpty {
            return String(localized: "최근 검색한 항목")
        } else {
            let format = String(localized: "%lld개의 항목")
            return String(format: format, filteredRecordings.count)
        }
    }

    private var recentItems: [String] {
        recentSearch
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    @State private var filteredRecordings: [Recording] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 300, height: 300)
                    .cornerRadius(350)
                    .blur(radius: 160)
                    .offset(x: -100, y: -368)
                VStack {
                    if searchedText.isEmpty {
                        if recentItems.isEmpty {
                            Text("최근 검색한 항목이 없습니다.")
                                .font(.callout)
                                .foregroundStyle(.lbl2)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity
                                )
                        } else {
                            List {
                                if !recordingSearcher.isLanguageModelAvailable {
                                    HStack(spacing: 10) {
                                        Image("Intelligence")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30)

                                        Text("Audiolog를 100% 활용해 보세요.")
                                            .font(.callout)
                                            .foregroundStyle(.lbl1)

                                        Spacer()
                                    }
                                    .listRowBackground(
                                        RoundedRectangle(cornerRadius: 28)
                                            .fill(.listBg)
                                    )
                                    .frame(height: 40)
                                    .listRowSeparator(.hidden)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPresenting = true
                                    }
                                }

                                ForEach(recentItems, id: \.self) {
                                    keyword in
                                    Button {
                                        searchText = keyword
                                        performSearch()
                                        isSearchFocused = false
                                    } label: {
                                        Text(keyword)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 10)
                                    }
                                    .listRowBackground(
                                        Color.clear
                                    )
                                }
                                .onDelete(perform: removeRecent)
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        if searchingWithAI {
                            VStack(spacing: 10) {
                                Text("항목을 탐색중입니다. 잠시만 기다려주세요.")
                                    .font(.callout)
                                    .foregroundStyle(.lbl2)

                                Text(
                                    "\(searchingIndex + 1) / \(recordings.count) 탐색중..."
                                )
                                .font(.callout)
                                .foregroundStyle(.lbl2)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            if filteredRecordings.isEmpty {
                                Text("검색된 항목이 없습니다.")
                                    .font(.callout)
                                    .foregroundStyle(.lbl2)
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity
                                    )
                            } else {
                                List {
                                    if !recordingSearcher
                                        .isLanguageModelAvailable
                                    {
                                        HStack(spacing: 10) {
                                            Image("Intelligence")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30)

                                            Text("Audiolog를 100% 활용해 보세요.")
                                                .font(.callout)
                                                .foregroundStyle(.lbl1)

                                            Spacer()
                                        }
                                        .padding(5)
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 28)
                                                .fill(.listBg)
                                        )
                                        .frame(height: 40)
                                        .listRowSeparator(.hidden)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            isPresenting = true
                                        }
                                    }

                                    ForEach(filteredRecordings) { item in
                                        HStack {
                                            HStack {
                                                VStack(
                                                    alignment: .leading,
                                                    spacing: 5
                                                ) {
                                                    Text(
                                                        item.isTitleGenerated
                                                            && !item.title
                                                                .isEmpty
                                                            ? item.title
                                                            : "제목 생성중.."
                                                    )
                                                    .font(.callout)
                                                    .foregroundStyle(
                                                        item.isTitleGenerated
                                                            ? .lbl1 : .lbl3
                                                    )

                                                    Text(
                                                        "\(item.createdAt.formatted("M월 d일 EEEE, a h:mm")) · \(item.formattedDuration)"
                                                    )
                                                    .font(.subheadline)
                                                    .foregroundStyle(.lbl2)
                                                    .accessibilityLabel(
                                                        Text(
                                                            "\(item.createdAt.formatted("M월 d일 EEEE a h시 mm분")) \(item.formattedDuration)"
                                                        )
                                                    )
                                                }

                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                audioPlayer.setPlaylist(
                                                    filteredRecordings
                                                )
                                                audioPlayer.load(item)
                                                audioPlayer.play()
                                            }

                                            Button {
                                                toggleFavorite(item)
                                            } label: {
                                                Image(
                                                    uiImage: UIImage(
                                                        named: item.isFavorite
                                                            ? "FavoriteOn"
                                                            : "FavoriteOff"
                                                    )!
                                                )
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20, height: 20)
                                            }
                                            .contentShape(Rectangle())
                                            .frame(width: 44, height: 44)
                                        }
                                        .padding(5)
                                        .listRowBackground(
                                            RoundedRectangle(cornerRadius: 28)
                                                .fill(.listBg)
                                        )
                                        .listRowSeparator(.hidden)
                                        .padding(.vertical, 5)
                                        .swipeActions(
                                            edge: .leading,
                                            allowsFullSwipe: false
                                        ) {
                                            Button {
                                                toggleFavorite(item)
                                            } label: {
                                                VStack {
                                                    Image(
                                                        systemName: item
                                                            .isFavorite
                                                            ? "star.slash"
                                                            : "star.fill"
                                                    )
                                                    Text(
                                                        item.isFavorite
                                                            ? "해제" : "즐겨찾기"
                                                    )
                                                }
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .accessibilityElement(
                                                    children: .ignore
                                                )
                                            }
                                            .tint(.main)
                                        }
                                        .tag(item.id)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityElement(children: .combine)
                                }
                                .listStyle(.insetGrouped)
                                .listRowSpacing(10)
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                    if !isSearchFocused {
                        MiniPlayerView()
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    }
                }
            }
            .background(.bg1)
            .navigationTitle(navTitle)
        }
        .onChange(of: searchText) {
            if searchText.isEmpty {
                searchedText = ""
                filteredRecordings = []
                searchTask?.cancel()
            }
        }
        .overlay {
            if searchingWithAI {
                GlownyEffect()
                    .transition(.opacity)
            }
        }
        .searchable(
            text: $searchText,
            prompt: recordingSearcher.isLanguageModelAvailable
                ? "어떤 추억을 찾아볼까요?" : "검색"
        )
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search) {
            performSearch()
        }
        .sheet(isPresented: $isPresenting) {
            AISuggestionView(isPresented: $isPresenting)
        }
        .task {
            await recordingSearcher.configureLanguageModelSession()
        }
        .task(id: externalQuery) {
            let q = externalQuery.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !q.isEmpty else { return }

            searchText = q
            saveRecent(q)

            let results = filteredRecordings
            if let first = results.first {
                audioPlayer.setPlaylist(results)
                audioPlayer.load(first)
                audioPlayer.play()
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }

    private func saveRecent(_ term: String) {
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        var set = OrderedSet(recentItems, caseInsensitive: true)
        set.bumpToFront(q)
        set.trim(max: 5)

        recentSearch = set.joined(separator: "\n")
    }

    private func removeRecent(at offsets: IndexSet) {
        var arr = recentItems
        arr.remove(atOffsets: offsets)
        recentSearch = arr.joined(separator: "\n")
    }

    private func clearRecent() {
        recentSearch = ""
    }

    private func toggleFavorite(_ item: Recording) {
        item.isFavorite.toggle()
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] favorite save failed: \(String(describing: error))"
            )
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchedText = query

        if recordingSearcher.isLanguageModelAvailable {
            filteredRecordings = []

            searchTask?.cancel()

            searchTask = Task {
                searchingWithAI = true
                searchingIndex = 0

                for (index, recording) in recordings.enumerated() {
                    if Task.isCancelled { break }

                    searchingIndex = index
                    logger.log(
                        "[SearchView] Comparing (\(index + 1)/\(recordings.count))"
                    )
                    if await recordingSearcher.compare(
                        searchText: query,
                        recording: recording
                    ) {
                        filteredRecordings.append(recording)
                    }
                }

                searchingWithAI = false
            }
        } else {
            filteredRecordings = recordings.filter {
                $0.title.localizedStandardContains(query)
            }
            saveRecent(searchedText)
            return
        }

        saveRecent(searchedText)
    }
}
