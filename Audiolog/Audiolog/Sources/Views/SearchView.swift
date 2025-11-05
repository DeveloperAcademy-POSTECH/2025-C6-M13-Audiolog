//
//  SearchView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @State private var searchText: String = ""

    private var filtered: [Recording] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return recordings }
        return recordings.filter { $0.title.localizedStandardContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { item in
                    Button {
                        Task { @MainActor in
                            audioPlayer.load(item)
                            audioPlayer.play()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
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
            .listStyle(.insetGrouped)
            .navigationTitle("검색")
        }
        .searchable(text: $searchText, prompt: "Search")
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
