//
//  ArchiveView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

struct ArchiveViewSub: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    var body: some View {
        Group {
            if recordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform",
                    description: Text(
                        "Start recording to see your archive here."
                    )
                )
            } else {
                List {
                    ForEach(recordings) { item in
                        Button {
                            Task { @MainActor in
                                print(
                                    "[ArchiveView] Loading recording: \(item.title)"
                                )
                                audioPlayer.load(item)
                                print(
                                    "[ArchiveView] Load completed for: \(item.title)"
                                )
                                // If you want a brief delay before starting playback, keep the next line.
                                // Otherwise, you can remove it.
                                // try? await Task.sleep(for: .milliseconds(150))
                                audioPlayer.play()
                                print(
                                    "[ArchiveView] Play invoked for: \(item.title)"
                                )
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
            }
        }
        .navigationTitle("Archive")
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
