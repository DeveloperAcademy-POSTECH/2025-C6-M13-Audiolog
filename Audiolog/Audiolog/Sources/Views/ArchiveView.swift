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
    @Binding var isSelecting: Bool

    @State private var editingId: UUID?
    @State private var tempTitle: String = ""
    @FocusState private var isEditingFocused: Bool
    @State private var pendingDelete: Recording?
    @State private var isShowingDeleteAlert: Bool = false
    @State private var selection = Set<UUID>()

    private var navTitle: String {
        if isSelecting {
            return selection.isEmpty ? "전체 로그 항목" : "\(selection.count)개 선택됨"
        } else {
            return "녹음 목록"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 400, height: 400)
                    .cornerRadius(350)
                    .blur(radius: 100)
                    .offset(x: -100, y: -320)

                List(selection: $selection) {
                    ForEach(recordings) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                if editingId == item.id && !isSelecting {
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
                                        item.isTitleGenerated
                                            && !item.title.isEmpty
                                            ? item.title : "제목 생성중.."
                                    )
                                    .font(.callout)
                                    .foregroundStyle(
                                        item.isTitleGenerated ? .lbl1 : .lbl3
                                    )
                                    .lineLimit(1)
                                }

                                HStack(spacing: 8) {
                                    Text(
                                        item.createdAt.formatted(
                                            "M월 d일 EEEE, a h:mm"
                                        )
                                    )
                                    Text("·")
                                    Text(item.formattedDuration)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .accessibilityHidden(true)
                            .disabled(isSelecting || editingId != nil)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.listBg)
                        )
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 5)
                        .onTapGesture {
                            guard editingId == nil, !isSelecting else { return }
                            Task { @MainActor in
                                audioPlayer.setPlaylist(recordings)
                                audioPlayer.load(item)
                                audioPlayer.play()
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !isSelecting && editingId == nil {
                                Button {
                                    toggleFavorite(item)
                                } label: {
                                    VStack {
                                        Image(
                                            systemName: item.isFavorite
                                            ? "star.slash" : "star.fill"
                                        )
                                        Text(item.isFavorite ? "해제" : "즐겨찾기")
                                    }
                                }
                                .tint(.main)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !isSelecting && editingId == nil {
                                Button {
                                    pendingDelete = item
                                    isShowingDeleteAlert = true
                                } label: {
                                    VStack {
                                        Image(
                                            systemName: "trash"
                                        )
                                        Text("삭제")
                                    }
                                }
                                .tint(.red1)

                                Button {
                                    editingId = item.id
                                    tempTitle = item.title
                                } label: {
                                    VStack {
                                        Image(
                                            systemName: "pencil"
                                        )

                                        Text("수정")
                                    }
                                }
                                .tint(.purple1)
                            }
                        }
                        .tag(item.id)
                    }
                }
            }
            .padding(.horizontal, 20)
            .listStyle(.plain)
            .listRowSpacing(10)
            .scrollContentBackground(.hidden)
            .alert("현재 녹음을 삭제하겠습니까?", isPresented: $isShowingDeleteAlert) {
                Button("삭제", role: .destructive) {
                    if let item = pendingDelete {
                        deleteOne(item)
                    }
                    pendingDelete = nil
                }
                Button("취소", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("삭제를 하면 되돌릴 수 없어요.")
            }
            .navigationTitle(navTitle)
            //            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar(isSelecting ? .hidden : .visible, for: .tabBar)
            .environment( \.editMode, .constant(isSelecting ? .active : .inactive) )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelecting ? "취소" : "선택") {
                        withAnimation {
                            isSelecting.toggle()
                        }
                        if !isSelecting {
                            selection.removeAll()
                            editingId = nil
                            isEditingFocused = false
                        } else {
                            editingId = nil
                            isEditingFocused = false
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting {
                        Button {
                            selectAll()
                        } label: {
                            Text("전체 선택")
                        }

                        Spacer()

                        Button {
                            deleteSelected()
                        } label: {
                            Label("삭제", systemImage: "trash")
                                .fontWeight(.semibold)
                        }
                        .disabled(selection.isEmpty)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            if isRecordCreated { isRecordCreated = false }
        }
    }

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

    @MainActor private func delete(_ items: [Recording]) {
        guard !items.isEmpty else { return }
        for it in items { modelContext.delete(it) }
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] delete save failed: \(String(describing: error))"
            )
        }
    }

    private func deleteOne(_ item: Recording) { delete([item]) }

    private func deleteSelected() {
        let targets = recordings.filter {
            selection.contains($0.id)
        }
        delete(targets)
        selection.removeAll()
    }

    private func selectAll() {
        // 비어 있으면 할 일 없음
        guard !recordings.isEmpty else {
            selection.removeAll()
            return
        }

        // 전부 선택되어 있으면 해제, 아니면 모두 선택
        if selection.count == recordings.count {
            selection.removeAll()
        } else {
            selection = Set(recordings.map { $0.id })
        }
    }

}
