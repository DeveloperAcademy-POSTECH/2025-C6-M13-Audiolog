//
//  AudiologWidgetExtensionLiveActivity.swift
//  AudiologWidgetExtension
//
//  Created by 성현 on 11/17/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AudiologWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AudiologWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AudiologWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AudiologWidgetExtensionAttributes {
    fileprivate static var preview: AudiologWidgetExtensionAttributes {
        AudiologWidgetExtensionAttributes(name: "World")
    }
}

extension AudiologWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: AudiologWidgetExtensionAttributes.ContentState {
        AudiologWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AudiologWidgetExtensionAttributes.ContentState {
         AudiologWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AudiologWidgetExtensionAttributes.preview) {
   AudiologWidgetExtensionLiveActivity()
} contentStates: {
    AudiologWidgetExtensionAttributes.ContentState.smiley
    AudiologWidgetExtensionAttributes.ContentState.starEyes
}
