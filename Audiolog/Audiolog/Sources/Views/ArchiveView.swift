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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavigationLink {
                    EmptyView()
                } label: {
                    Title2(text: "로그 보관함")
                }
                .tint(.primary)
                .disabled(true)  // TODO: 구현

                VStack(spacing: 10) {
                    ForEach(lastThreeDaysSections(), id: \.date) { section in
                        Button {
                            if let first = section.items.first {
                                Task { @MainActor in
                                    audioPlayer.load(first)
                                    audioPlayer.play()
                                }
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

                NavigationLink {
                    EmptyView()
                } label: {
                    Title2(text: "추억 보관함")
                }
                .tint(.primary)
                .disabled(true)  // TODO: 구현

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 10)
                        ForEach(sampleMemories, id: \.self) { title in
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 200)
                                Text(title)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer().frame(width: 10)
                    }
                }
            }
            .padding(.vertical)
        }
        .overlay {
            if recordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform",
                    description: Text(
                        "Start recording to see your archive here."
                    )
                )
            }
        }
        .animation(.default, value: recordings)
    }
}

// MARK: - Helpers
extension ArchiveView {
    fileprivate struct DaySection: Identifiable {
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

    fileprivate func lastThreeDaysSections() -> [DaySection] {
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

    fileprivate var sampleMemories: [String] {
        ["2025년 여름", "2025년 여름", "봄 소리", "가을 산책"]
    }

    fileprivate func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
