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
    /// (제목, 개수) 튜플 배열 – 공통 모델 없이 사용
    let categories: [(String, Int)]
}
