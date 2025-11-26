//
//  WeatherAttributionView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/27/25.
//

import SwiftUI

struct WeatherAttributionView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("날씨 데이터는  Weather에서 제공합니다.")
            
            Link("법적 고지 보기",
                 destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
