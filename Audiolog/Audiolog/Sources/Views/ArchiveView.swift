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
    @Environment(AudioProcessor.self) private var audioProcessor

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    @Binding var isRecordCreated: Bool
    @Binding var isIntelligenceEnabled: Bool
    @State private var isPresenting = false

    @State private var editingId: UUID?
    @State private var tempTitle: String = ""
    @FocusState private var isEditingFocused: Bool
    @State private var pendingDelete: Recording?
    @State private var isShowingDeleteAlert: Bool = false
    @State private var isShowingBulkDeleteAlert: Bool = false
    @State private var bulkDeleteCount: Int = 0
    @State private var selection = Set<UUID>()
    @State private var isSelecting: Bool = false

    private var navTitle: String {
        return selection.isEmpty ? "전체 로그" : "\(selection.count)개 선택됨"
    }
    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.sub)
                    .frame(width: 300, height: 300)
                    .cornerRadius(350)
                    .blur(radius: 100)
                    .offset(x: -100, y: -320)

                VStack(spacing: 0) {
                    if recordings.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("아직 저장된 로그가 없어요")
                                .font(.title3)
                                .foregroundStyle(.lbl2)
                            Text("녹음 탭에서 새로운 로그를 만들어 보세요")
                                .font(.footnote)
                                .foregroundStyle(.lbl3)
                            Spacer()
                                .frame(height: 20)
                        }
                        Spacer()
                    } else {
                        List(selection: $selection) {
                            if audioProcessor.isLanguageModelAvailable {
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
                                .padding(.horizontal, 20)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.listStroke)
                                        .padding(.horizontal, 20)
                                )
                                .frame(height: 40)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isPresenting = true
                                }
                            }
                            ForEach(recordings) { item in
                                HStack {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5)
                                        {
                                            if editingId == item.id
                                                && !isSelecting
                                            {
                                                TextField(
                                                    "제목",
                                                    text: $tempTitle
                                                )
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
                                                        ? item.title
                                                        : "제목 생성중.."
                                                )
                                                .font(.callout)
                                                .foregroundStyle(
                                                    item.isTitleGenerated
                                                        ? .lbl1 : .lbl3
                                                )
                                            }

                                            Text(
                                                "\(item.createdAt.formatted("M월 d일 EEEE a h:mm")) · \(item.formattedDuration)"
                                            )
                                            .font(.subheadline)
                                            .foregroundStyle(.lbl2)
                                            .accessibilityLabel(
                                                Text(
                                                    "\(item.createdAt.formatted("M월 d일 EEEE a h:mm")) \(item.formattedDuration)"
                                                )
                                            )
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard editingId == nil, !isSelecting
                                        else {
                                            return
                                        }
                                        audioPlayer.setPlaylist(recordings)
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
                                    .disabled(isSelecting || editingId != nil)
                                    .accessibilityHidden(true)
                                }
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.listBg)
                                        .padding(.horizontal, 20)
                                )
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 20)
                                .swipeActions(
                                    edge: .leading,
                                    allowsFullSwipe: false
                                ) {
                                    if !isSelecting && editingId == nil {
                                        Button {
                                            toggleFavorite(item)
                                        } label: {
                                            VStack {
                                                Image(
                                                    systemName: item.isFavorite
                                                        ? "star.slash"
                                                        : "star.fill"
                                                )
                                                Text(
                                                    item.isFavorite
                                                        ? "즐겨찾기 해제" : "즐겨찾기"
                                                )
                                            }
                                        }
                                        .tint(.main)
                                    }
                                }
                                .swipeActions(
                                    edge: .trailing,
                                    allowsFullSwipe: false
                                ) {
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

                                        if let url = fileURL(for: item) {
                                            ShareLink(item: url) {
                                                VStack {
                                                    Image(
                                                        systemName:
                                                            "square.and.arrow.up"
                                                    )
                                                    Text("공유")
                                                }
                                            }
                                            .tint(.accent)
                                        }
                                    }
                                }
                                .tag(item.id)
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                    }

                    if !isSelecting && !isEditingFocused {
                        MiniPlayerView()
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                    }
                }
            }
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
            .alert(
                "\(bulkDeleteCount)개의 녹음을 삭제하시겠습니까?",
                isPresented: $isShowingBulkDeleteAlert
            ) {
                Button("삭제", role: .destructive) {
                    deleteSelected()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제하시면 되돌릴 수 없어요.")
            }
            .navigationTitle(navTitle)
            .toolbar(isSelecting ? .hidden : .visible, for: .tabBar)
            .environment(
                \.editMode,
                .constant(isSelecting ? .active : .inactive)
            )
            .toolbar {
                ToolbarItem {
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
            .sheet(isPresented: $isPresenting) {
                AISuggestionView(isPresented: $isPresenting)
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting {
                        ShareLink(items: selectedFileURLs) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(selectedFileURLs.isEmpty)

                        Spacer()

                        Button {
                            bulkDeleteCount = selection.count
                            isShowingBulkDeleteAlert = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                                .fontWeight(.semibold)
                        }
                        .disabled(selection.isEmpty)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(.bg1)
        }
        .onAppear {
            if isRecordCreated { isRecordCreated = false }
        }
    }

    private var selectedFileURLs: [URL] {
        recordings
            .filter { selection.contains($0.id) }
            .compactMap { fileURL(for: $0) }
    }

    private func fileURL(for recording: Recording) -> URL? {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()

        let fileURL = documentURL.appendingPathComponent(fileName)

        return fileURL
    }

    private func commitEdit(for item: Recording) {
        let newTitle = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
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

    private func delete(_ items: [Recording]) {
        guard !items.isEmpty else { return }
        for item in items {
            if item == audioPlayer.current {
                audioPlayer.currentItemDeleted()
            }
            modelContext.delete(item)
        }
        do { try modelContext.save() } catch {
            logger.log(
                "[ArchiveView] delete save failed: \(String(describing: error))"
            )
        }
    }

    private func deleteOne(_ item: Recording) {
        withAnimation { delete([item]) }
    }

    private func deleteSelected() {
        let targets = recordings.filter {
            selection.contains($0.id)
        }
        delete(targets)
        selection.removeAll()
    }
}
