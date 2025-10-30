//
//  ListRow2.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct ListRow2: View {
    let title: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(sub)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 15)
        .overlay(
            alignment: .bottom,
            content: {
                Rectangle()
                    .inset(by: 0.25)
                    .stroke(.tertiary, lineWidth: 0.5)
                    .frame(height: 0.5)
            }
        )
    }
}
