//
//  Title.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct Title3: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
    }
}

#Preview {
    Title3(text: "title")
}
