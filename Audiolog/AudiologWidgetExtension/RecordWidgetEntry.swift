//
//  RecordWidgetEntry.swift
//  Audiolog
//
//  Created by 성현 on 11/17/25.
//

import WidgetKit
import SwiftUI

struct RecordWidgetEntry: TimelineEntry {
    let date: Date
    let categories: [(String, Int)]
}
