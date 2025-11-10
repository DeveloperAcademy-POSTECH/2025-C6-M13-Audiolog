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

    @Binding var isRecordCreated: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(recordings) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.isTitleGenerated && !item.title.isEmpty ? item.title : "제목 생성중")
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

                        Button {
                            item.isFavorite.toggle()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .imageScale(.large)
                                .font(.title3)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)   // 보이스 오버 포서킹 해제, 예시 코드로 적어두었어요 (추후에 고려해야할 사항)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { @MainActor in
                            audioPlayer.setPlaylist(recordings)
                            audioPlayer.load(item)
                            audioPlayer.play()
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton) // 즐겨찾기를 제외한 행을 버튼으로 포커싱
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            item.isFavorite.toggle()
                            try? modelContext.save()
                        } label: {
                            Label(item.isFavorite ? "해제" : "즐겨찾기",
                                  systemImage: item.isFavorite ? "star.slash" : "star.fill")
                        }
                        .tint(item.isFavorite ? .blue : .blue)
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("녹음 목록")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if isRecordCreated { isRecordCreated = false }
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
