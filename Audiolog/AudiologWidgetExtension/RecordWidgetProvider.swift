//
//  RecordWidgetProvider.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import WidgetKit

struct RecordWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordWidgetEntry {
        RecordWidgetEntry(
            date: Date(),
            categories: [("즐겨찾기", 3), ("파도소리", 2)]
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (RecordWidgetEntry) -> Void
    ) {
        let cats = loadCategories()
        completion(
            RecordWidgetEntry(
                date: Date(),
                categories: cats
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<RecordWidgetEntry>) -> Void
    ) {
        let cats = loadCategories()

        let entry = RecordWidgetEntry(
            date: Date(),
            categories: cats
        )
        let nextUpdate =
            Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadCategories() -> [(String, Int)] {
        let defaults = UserDefaults(suiteName: "group.seancho.audiolog")

        guard
            let dict = defaults?.dictionary(forKey: "recap_items_dict")
                as? [String: Int],
            !dict.isEmpty
        else {
            return []
        }

        return
            dict
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
}
