//
//  Toast.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct Toast: View {
    var body: some View {
        Text("소리가 저장되었어요.")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.lbl1)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background {
                Capsule().fill(.bgToast)
            }
            .frame(height: 45)
    }
}

#Preview {
    Toast()
}
