//
//  SearchView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

private enum RecentSearch {
    static let data = "RecentSearch"
}

struct SearchView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(AudioProcessor.self) private var audioProcessor

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var searchText: String = ""
    @State private var searchedText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var searchingWithAI: Bool = false

    @Binding var externalQuery: String
    @Binding var isIntelligenceEnabled: Bool
    @State private var isPresenting = false

    @AppStorage(RecentSearch.data) private var recentSearch: String = ""

    private var navTitle: String {
        return searchText.isEmpty
            ? "최근 검색한 항목" : "\(filteredRecordings.count)개의 항목"
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
            VStack {
                if searchedText.isEmpty {
                    List {
                        if !audioProcessor.isLanguageModelAvailable {
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

                        if recentItems.isEmpty {
                            Text("최근 검색한 항목이 없습니다.")
                                .font(.callout)
                                .foregroundStyle(.lbl2)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(.clear)
                                )
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(recentItems, id: \.self) {
                                keyword in
                                Button {
                                    searchText = keyword
                                } label: {
                                    Text(keyword)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 10)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.bg1)
                                        .padding(.horizontal, 20)
                                )
                            }
                            .onDelete(perform: removeRecent)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    List {
                        if !audioProcessor.isLanguageModelAvailable {
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
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(
                                            item.isTitleGenerated
                                                && !item.title.isEmpty
                                                ? item.title : "제목 생성중.."
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
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    audioPlayer.setPlaylist(filteredRecordings)
                                    audioPlayer.load(item)
                                    audioPlayer.play()
                                }

                                Button {
                                    toggleFavorite(item)
                                } label: {
                                    Image(
                                        uiImage: UIImage(
                                            named: item.isFavorite
                                                ? "FavoriteOn" : "FavoriteOff"
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
                                            systemName: item.isFavorite
                                                ? "star.slash" : "star.fill"
                                        )
                                        Text(
                                            item.isFavorite ? "해제" : "즐겨찾기"
                                        )
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(
                                        Text(
                                            "\(item.createdAt.formatted("M월 d일 EEEE a h:mm")) \(item.formattedDuration)"
                                        )
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
            .overlay(alignment: .bottom) {
                if !isSearchFocused {
                    MiniPlayerView()
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
            }
            .background(.bg1)
            .navigationTitle(navTitle)
        }
        .onChange(of: searchText) {
            if searchText.isEmpty { searchedText = "" }
        }
        .overlay {
            if audioProcessor.isLanguageModelAvailable {
                GlownyEffect()
            }
        }
        .searchable(
            text: $searchText,
            prompt: audioProcessor.isLanguageModelAvailable
                ? "어떤 추억을 찾아볼까요?" : "검색"
        )
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search) {
            searchedText = searchText
            if audioProcessor.isLanguageModelAvailable {
                searchingWithAI = true

                // TODO: FoundationModel 혹은 NaturalLanguage처리를 통해 연관있는 Recording들 가져오기
                filteredRecordings = []

                searchingWithAI = false
            } else {
                let q = searchedText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                filteredRecordings = recordings.filter {
                    $0.title.localizedStandardContains(q)
                }
                return
            }

            return
                saveRecent(searchedText)
        }
        .sheet(isPresented: $isPresenting) {
            AISuggestionView(isPresented: $isPresenting)
        }
        .task(id: externalQuery) {
            let q = externalQuery.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !q.isEmpty else { return }

            // Intent에서 넘어온 검색어로 검색 시작
            searchText = q
            saveRecent(q)

            let results = filteredRecordings
            if let first = results.first {
                audioPlayer.setPlaylist(results)
                audioPlayer.load(first)
                audioPlayer.play()
            }
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
}
