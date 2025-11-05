//
//  RecapView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/5/25.
//

import SwiftUI

struct RecapView: View {
    private var sampleMemories: [String] {
        ["2025년 가을", "2025년 여름", "봄 소리", "가을 산책"]
    }

    var recapCategoryButtonWidth: CGFloat {
        (screenWidth - 60) / 2
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                let columns = [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(sampleMemories, id: \.self) { title in
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.2))
                                .frame(
                                    width: recapCategoryButtonWidth,
                                    height: recapCategoryButtonWidth
                                )
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("추억 보관함")
        }
    }
}
