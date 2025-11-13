//
//  SearchView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

// AppStorage로 최근 검색 저장, 최대 5개
private enum RecentSearch {
    static let data = "RecentSearch"
}

struct SearchView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    @AppStorage(RecentSearch.data) private var recentSearch: String = ""

    private var recentItems: [String] {
        recentSearch
            .split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    private var filtered: [Recording] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return recordings }
        return recordings.filter { $0.title.localizedStandardContains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    Title(text: "최근 검색한 항목")

                    VStack {
                        if recentItems.isEmpty {
                            Text("최근 검색한 항목이 없습니다.")
                                .font(.callout)
                                .foregroundStyle(.lbl2)
                                .offset(x: 0, y: 0)
                        } else {
                            List {
                                ForEach(recentItems, id: \.self) {
                                    keyword in
                                    Button {
                                        searchText = keyword
                                    } label: {
                                        Text(keyword)
                                            .lineLimit(1)
                                            .padding(.vertical, 10)
                                    }
                                    .listRowBackground(
                                        Color.bg1
//                                        Rectangle().fill(.bg1)
                                    )
                                }
                                .onDelete(perform: removeRecent)
                            }
                            .listStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Title(text: "검색 결과")

                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                        Text("\(filtered.count)개의 항목")
                            .font(.callout.weight(.semibold))
                    }
                    .padding(.leading, 20)
                    .foregroundStyle(.lbl2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    List {
                        ForEach(filtered) { item in
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
                                        .lineLimit(1)

                                        Text(
                                            "\(item.createdAt.formatted("M월 d일 EEEE, a h:mm")) · \(item.formattedDuration)"
                                        )
                                        .lineLimit(1)
                                        .font(.subheadline)
                                        .foregroundStyle(.lbl2)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    audioPlayer.setPlaylist(filtered)
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
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(.listBg)
                            )
                            .listRowSeparator(.hidden)
                            .padding(5)
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
                                    .accessibilityLabel(Text(
                                        "\(item.createdAt.formatted("M월 d일 EEEE a h:mm")) \(item.formattedDuration)"
                                    ))
                                }
                                .tint(.main)
                            }
                            .tag(item.id)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                    .padding(.horizontal, 20)
                    .listStyle(.plain)
                    .listRowSpacing(10)
                    .scrollContentBackground(.hidden)
                }
            }
            .overlay(alignment: .bottom) {
                VStack {
                    Spacer()
                    if !isSearchFocused {
                        MiniPlayerView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
            .background(.bg1)
        }
        .searchable(text: $searchText, prompt: "Search")
        .searchFocused($isSearchFocused)
        .onSubmit(of: .search) {
            saveRecent(searchText)
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
