//
//  Title.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct Title2: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Text(text)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
    }
}

#Preview {
    Title2(text: "title")
}
