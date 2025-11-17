//
//  AudiologWidgetExtensionBundle.swift
//  AudiologWidgetExtension
//
//  Created by 성현 on 11/17/25.
//

import WidgetKit
import SwiftUI

@main
struct AudiologWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        StartRecordingWidget()
        AudiologWidgetExtensionControl()
        AudiologWidgetExtensionLiveActivity()
    }
}
