//
//  AudiologWidgetExtensionControl.swift
//  AudiologWidgetExtension
//
//  Created by 성현 on 11/17/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct AudiologWidgetExtensionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "SeanCho.Audiolog.AudiologWidgetExtension251117",
            provider: Provider()
        ) { _ in
            ControlWidgetButton(
                "녹음 시작",
                action: StartRecordingIntent()
            ) { _ in
                Label("녹음 시작", systemImage: "ear")
//                Label {
//                    Text("녹음 시작")
//                } icon: {
//                    Image("QuickActionIcon")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 50, height: 50)
//                }
            }
        }
        .displayName("녹음 시작")
        .description("누르면 녹음을 시작합니다.")
    }
}

extension AudiologWidgetExtensionControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            return false
        }
    }
}
