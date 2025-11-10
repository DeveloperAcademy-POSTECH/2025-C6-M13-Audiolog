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
            if searchText.isEmpty {
                if isSearchFocused {
                    Title(text: "최근 검색한 항목_포커스")
                    Spacer()
                    if recentItems.isEmpty {
                        Text("최근 검색한 항목이 없습니다.")
                    } else {

                        List {
                            Section {
                                ForEach(recentItems, id: \.self) { keyword in
                                    Button {
                                        searchText = keyword
                                    } label: {
                                        HStack {
                                            Text(keyword)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .onDelete(perform: removeRecent)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    Title(text: "최근 검색한 항목")
                    Spacer()
                    if recentItems.isEmpty {
                        Text("최근 검색한 항목이 없습니다.")
                    } else {
                        List {
                            Section {
                                ForEach(recentItems, id: \.self) { keyword in
                                    Button {
                                        searchText = keyword
                                    } label: {
                                        HStack {
                                            Text(keyword)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .onDelete(perform: removeRecent)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            } else {
                Title(text: "검색 결과")

                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("\(filtered.count)개의 항목")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.trailing, 10)
                .padding(.vertical, 10)

                List {
                    ForEach(filtered) { item in
                        Button {
                            Task { @MainActor in
                                saveRecent(searchText)
                                audioPlayer.load(item)
                                audioPlayer.play()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Text(item.formattedDuration)
                                        Text("·")
                                        Text(item.createdAt, style: .date)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
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
}
