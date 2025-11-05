//
//  ArchiveView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/28/25.
//

import SwiftData
import SwiftUI

struct ArchiveView: View {
    // Audio & data
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [
        SortDescriptor<Recording>(\Recording.createdAt, order: .reverse)
    ]) private var recordings: [Recording]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink {
                        ArchiveListView()
                    } label: {
                        Title2(text: "로그 보관함")
                    }
                    .tint(.primary)

                    VStack(spacing: 10) {
                        ForEach(lastThreeDaysSections(), id: \.date) {
                            section in
                            Button {
                                let items = section.items
                                guard !items.isEmpty else { return }
                                Task { @MainActor in
                                    audioPlayer.setPlaylist(items)
                                    audioPlayer.playFromStart()
                                }
                            } label: {
                                ListRow2(
                                    title: section.dateFormatted,
                                    sub: "\(section.items.count)개의 녹음"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical)
            }
            .animation(.default, value: recordings)
        }
    }

    private struct DaySection: Identifiable {
        var id: Date { date }
        let date: Date
        let items: [Recording]
        var dateFormatted: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M월 d일 EEEE"
            return formatter.string(from: date)
        }
    }

    private func lastThreeDaysSections() -> [DaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (0..<3).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        // Group recordings by day
        let grouped = Dictionary(grouping: recordings) { rec in
            calendar.startOfDay(for: rec.createdAt)
        }

        return days.map { day in
            DaySection(date: day, items: grouped[day] ?? [])
        }
    }

    fileprivate func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
