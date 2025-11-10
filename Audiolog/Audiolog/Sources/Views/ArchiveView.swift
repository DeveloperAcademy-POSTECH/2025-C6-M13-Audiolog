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

    @State private var editingId: UUID? = nil
    @State private var tempTitle: String = ""
    @FocusState private var isEditingFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(recordings) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if editingId == item.id {
                                TextField("제목", text: $tempTitle)
                                    .focused($isEditingFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitEdit(for: item)
                                    }
                                    .onAppear {
                                        isEditingFocused = true
                                    }
                            } else {
                                Text(
                                    item.isTitleGenerated && !item.title.isEmpty
                                        ? item.title : "제목 생성중"
                                )
                                .font(.headline)
                                .lineLimit(1)
                                .opacity(item.isTitleGenerated ? 1 : 0.6)
                            }

                            HStack(spacing: 8) {
                                Text(item.formattedDuration)
                                Text("·")
                                Text(item.createdAt, style: .date)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // ⭐️ 즐겨찾기 (VoiceOver 포커스 제외)
                        Button {
                            toggleFavorite(item)
                        } label: {
                            Image(
                                systemName: item.isFavorite
                                    ? "star.fill" : "star"
                            )
                            .imageScale(.large)
                            .font(.title3)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHidden(true)  // 보이스오버 포커싱 제외
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard editingId == nil else { return }
                        Task { @MainActor in
                            audioPlayer.setPlaylist(recordings)
                            audioPlayer.load(item)
                            audioPlayer.play()
                        }
                    }

                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            toggleFavorite(item)
                        } label: {
                            Label(
                                item.isFavorite ? "해제" : "즐겨찾기",
                                systemImage: item.isFavorite
                                    ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(item.isFavorite ? .gray : .yellow)
                    }

                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editingId = item.id
                            tempTitle = item.title
                        } label: {
                            Label("수정", systemImage: "pencil")
                        }
                        .tint(.blue)
                        .disabled(editingId != nil)

                        Button(role: .destructive) {
                            deleteOne(item)
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                        .disabled(editingId != nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("녹음 목록")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if isRecordCreated { isRecordCreated = false }
        }
    }

//    private func delete(at offsets: IndexSet) {
//        let items = offsets.map { recordings[$0] }
//        for item in items {
//            modelContext.delete(item)
//        }
//    }

    private func commitEdit(for item: Recording) {
        let newTitle = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
            // 빈 제목이면 편집 종료만
            editingId = nil
            return
        }
        item.title = newTitle
        item.isTitleGenerated = true
        do {
            try modelContext.save()
        } catch {
            logger.log(
                "[ArchiveView] title save failed: \(String(describing: error))"
            )
        }
        editingId = nil
        isEditingFocused = false
    }

    private func toggleFavorite(_ item: Recording) {
        item.isFavorite.toggle()
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] favorite save failed: \(String(describing: error))"
            )
        }
    }

    private func deleteOne(_ item: Recording) {
        modelContext.delete(item)
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] delete save failed: \(String(describing: error))"
            )
        }
    }

}
