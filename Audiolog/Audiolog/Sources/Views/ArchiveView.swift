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

    @State private var range: ArchiveRange = .day

    private enum ArchiveRange: Hashable {
        case day
        case month
        case year
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack {
                Picker("범위", selection: $range) {
                    Text("Day").tag(ArchiveRange.day)
                    Text("Month").tag(ArchiveRange.month)
                    Text("Year").tag(ArchiveRange.year)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        NavigationLink {
                            ArchiveListView()
                        } label: {
                            Title2(text: "로그 보관함")
                        }
                        .tint(.primary)

                        VStack(spacing: 10) {
                            let sections = sectionsForCurrentRange()
                            ForEach(sections, id: \.date) {
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
            .navigationTitle("dd")
            .navigationBarTitleDisplayMode(.inline)
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

    private struct MonthSection: Identifiable {
        var id: Date { monthStart }
        let monthStart: Date
        let items: [Recording]
        var dateFormatted: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy년 M월"
            return formatter.string(from: monthStart)
        }
        var date: Date { monthStart }
    }

    private struct YearSection: Identifiable {
        var id: Date { yearStart }
        let yearStart: Date
        let items: [Recording]
        var dateFormatted: String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy년"
            return formatter.string(from: yearStart)
        }
        var date: Date { yearStart }
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

    private func lastThreeMonthsSections() -> [MonthSection] {
        let calendar = Calendar.current
        let today = Date()
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        )!
        let months: [Date] = (0..<3).compactMap { offset in
            calendar.date(
                byAdding: .month,
                value: -offset,
                to: currentMonthStart
            )
        }
        let grouped = Dictionary(grouping: recordings) { rec in
            calendar.date(
                from: calendar.dateComponents(
                    [.year, .month],
                    from: rec.createdAt
                )
            )!
        }
        return months.map { monthStart in
            MonthSection(
                monthStart: monthStart,
                items: grouped[monthStart] ?? []
            )
        }
    }

    private func lastThreeYearsSections() -> [YearSection] {
        let calendar = Calendar.current
        let today = Date()
        let currentYearStart = calendar.date(
            from: calendar.dateComponents([.year], from: today)
        )!
        let years: [Date] = (0..<3).compactMap { offset in
            calendar.date(byAdding: .year, value: -offset, to: currentYearStart)
        }
        let grouped = Dictionary(grouping: recordings) { rec in
            calendar.date(
                from: calendar.dateComponents([.year], from: rec.createdAt)
            )!
        }
        return years.map { yearStart in
            YearSection(yearStart: yearStart, items: grouped[yearStart] ?? [])
        }
    }

    private func sectionsForCurrentRange() -> [DaySection] {
        switch range {
        case .day:
            return lastThreeDaysSections()
        case .month:
            return lastThreeMonthsSections().map { month in
                DaySection(date: month.monthStart, items: month.items)
            }
        case .year:
            return lastThreeYearsSections().map { year in
                DaySection(date: year.yearStart, items: year.items)
            }
        }
    }

    fileprivate func delete(at offsets: IndexSet) {
        let items = offsets.map { recordings[$0] }
        for item in items {
            modelContext.delete(item)
        }
    }
}
