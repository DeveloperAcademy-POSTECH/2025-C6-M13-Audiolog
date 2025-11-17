// RecordWidgetView.swift

import SwiftUI
import WidgetKit
import AppIntents

struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RecordWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                // 여기서 실제 배경색 지정
                // Asset 에 "WidgetBackground" 있으면 그거 쓰고,
                // 없으면 Color(.systemBackground) 정도로
                Color("WidgetBackground")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    private var smallView: some View {
        Button(intent: StartRecordingIntent()) {
            VStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .bold))
                Text("소리를 담아보세요")
                    .font(.footnote.weight(.semibold))
            }
        }
        .buttonStyle(.borderedProminent)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("추억을 회상해보세요")
                .font(.headline)

            ForEach(entry.categories.prefix(2), id: \.0) { title, count in
                HStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body.weight(.semibold))
                        Text("\(count)개의 항목")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(intent: PlayRecapCategoryIntent(category: title)) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                    }
                }
            }
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading) {
                    Text("오늘의 소리를")
                    Text("담아보세요")
                }
                .font(.title2.bold())

                Spacer()

                Button(intent: StartRecordingIntent()) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.blue)
                        )
                }
            }

            Text("추억을 회상해보세요")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(entry.categories.prefix(3), id: \.0) { title, count in
                    HStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.body.weight(.semibold))
                            Text("\(count)개의 항목")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(intent: PlayRecapCategoryIntent(category: title)) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 26))
                        }
                    }
                }
            }
        }
        .padding()
    }
}
