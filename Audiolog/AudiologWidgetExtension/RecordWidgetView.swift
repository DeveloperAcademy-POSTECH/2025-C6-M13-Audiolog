// RecordWidgetView.swift

import AppIntents
import SwiftUI
import WidgetKit

struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: RecordWidgetEntry

    var body: some View {
        content
            .containerRelativeFrame(.horizontal)
            .containerBackground(.listStroke, for: .widget)
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
        VStack(alignment: .leading, spacing: 0) {
            Button(
                intent: StartRecordingIntent()
            ) {
                Image(systemName: "microphone.fill")
                    .font(.system(size: 23))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 60, height: 60)
                    .background(
                        ZStack {
                            Circle().fill(.main.opacity(0.5))
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(1),
                                            Color.sub.opacity(0.4),
                                            Color.main.opacity(0.4),
                                            Color.white.opacity(1),
                                            Color.sub.opacity(0.4),
                                            Color.main.opacity(0.4),
                                            Color.white.opacity(1),
                                        ]),
                                        center: .center
                                    ),
                                    lineWidth: 1
                                )
                                .blur(radius: 0.4)
                                .padding(0.5)
                        }
                    )
            }
            .buttonStyle(.plain)
            Text("소리를 담아보세요")
                .font(.system(size: 15).bold())
                .foregroundStyle(.accent)
                .padding(.top, 22)
            Text("Audiolog")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.lbl2)
                .padding(.top, 5)
        }
        .padding(16)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("추억을 회상해보세요")
                .font(.system(size: 15).bold())
                .foregroundStyle(.accent)
            VStack(spacing: 10) {
                ForEach(entry.categories.prefix(2), id: \.0) { title, count in
                    HStack {
                        let asciiSum = title.unicodeScalars.map { Int($0.value) }.reduce(0, +)
                        let thumbnailName = "Thumbnail\(((asciiSum % 7) + 1))"
                        Image(thumbnailName)
                            .resizable()
                            .cornerRadius(10)
                            .frame(width: 40, height: 40)
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(title)
                                .font(.system(size: 15).weight(.semibold))
                                .foregroundStyle(.lbl1)
                            Text("\(count)개의 항목")
                                .font(.footnote)
                                .foregroundStyle(.lbl2)
                        }
                        Spacer()
                        Button(
                            intent: PlayRecapCategoryIntent(category: title)
                        ) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.sub))
                        }
                        .buttonStyle(.plain)
                    }
                }

            }
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("오늘의 소리를\n담아보세요")
                        .font(.title2.bold())
                        .foregroundStyle(.accent)
                    Text("Audiolog")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.lbl2)
                        .padding(.bottom, 20)
                }
                Spacer()
                Button(
                    intent: StartRecordingIntent()
                ) {
                    Image(systemName: "microphone.fill")
                        .font(.system(size: 23))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 60, height: 60)
                        .background(
                            ZStack {
                                Circle().fill(.main.opacity(0.5))
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(1),
                                                Color.sub.opacity(0.4),
                                                Color.main.opacity(0.4),
                                                Color.white.opacity(1),
                                                Color.sub.opacity(0.4),
                                                Color.main.opacity(0.4),
                                                Color.white.opacity(1),
                                            ]),
                                            center: .center
                                        ),
                                        lineWidth: 1
                                    )
                                    .blur(radius: 0.4)
                                    .padding(0.5)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            VStack(alignment: .leading, spacing: 12) {
                Text("추억을 회상해보세요")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.lbl2)

                VStack(spacing: 15) {
                    ForEach(entry.categories.prefix(3), id: \.0) {
                        title,
                        count in
                        HStack {
                            let asciiSum = title.unicodeScalars.map { Int($0.value) }.reduce(0, +)
                            let thumbnailName = "Thumbnail\(((asciiSum % 7) + 1))"
                            Image(thumbnailName)
                                .resizable()
                                .cornerRadius(10)
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.body.weight(.semibold))
                                Text("\(count)개의 항목")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(
                                intent: PlayRecapCategoryIntent(category: title)
                            ) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.sub)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(.listStroke))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.listBg)
        }
    }
}
