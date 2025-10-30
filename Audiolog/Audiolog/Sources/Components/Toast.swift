//
//  Toast.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct Toast: View {
    var body: some View {
        Text("녹음이 종료되었어요.")
            .font(
                Font.footnote
                    .weight(.semibold)
            )
            .foregroundStyle(.background)
            .padding(10)
            .background {
                Capsule().fill(.primary)
            }
    }
}

#Preview {
    Toast()
}
