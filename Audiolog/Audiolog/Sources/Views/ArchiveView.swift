//
//  ArchiveView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    var body: some View {
        NavigationStack {
            List {
                ForEach(recordings) { item in
                    Button {
                        Task { @MainActor in
                            audioPlayer.setPlaylist(recordings)
                            audioPlayer.load(item)
                            audioPlayer.play()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayTitle)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .opacity(item.isTitleGenerated ? 1 : 0.6)
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
            .navigationTitle("녹음 목록")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
