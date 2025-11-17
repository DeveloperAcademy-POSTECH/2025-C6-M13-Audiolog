//
//  AudiologWidgetExtension.swift
//  AudiologWidgetExtension
//
//  Created by 성현 on 11/17/25.
//

import WidgetKit
import SwiftUI

struct AudiologWidgetBundle: WidgetBundle {
    var body: some Widget {
        StartRecordingWidget()
    }
}

struct StartRecordingWidget: Widget {
    let kind: String = "StartRecordingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: RecordWidgetProvider()
        ) { entry in
            RecordWidgetView(entry: entry)
        }
        .configurationDisplayName("빠른 녹음")
        .description("Audiolog에서 한 번에 새 녹음을 시작합니다.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}
