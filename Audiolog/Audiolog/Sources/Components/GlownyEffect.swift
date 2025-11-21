//
//  GlownyEffect.swift
//  Audiolog
//
//  Created by Sean Cho on 11/21/25.
//

import SwiftUI

private struct GlowEffect {
    static func generateGradientStops() -> [Gradient.Stop] {
        [
            Gradient.Stop(color: Color.intelligence1.opacity(0.8), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color.intelligence2.opacity(0.8), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color.intelligence3.opacity(0.8), location: Double.random(in: 0...1)),
            Gradient.Stop(color: Color.intelligence4.opacity(0.8), location: Double.random(in: 0...1)),
        ]
        .sorted { $0.location < $1.location }
    }
}

private struct Effect: View {
    var gradientStops: [Gradient.Stop]
    var width: CGFloat
    var blur: CGFloat

    var body: some View {
        LinearGradient(stops: gradientStops,
                       startPoint: .leading,
                       endPoint: .trailing)
        .frame(height: width)
        .blur(radius: blur)
    }
}

struct GlownyEffect: View {
    @State private var gradientStops: [Gradient.Stop] = []

    var body: some View {
        GeometryReader { _ in
            let thickness: CGFloat = 13

            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        LinearGradient(stops: gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: thickness
                    )
                    .blur(radius: 17)
                    .allowsHitTesting(false)
            }
            .onAppear {
                gradientStops = GlowEffect.generateGradientStops()

                Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.8)) {
                        gradientStops = GlowEffect.generateGradientStops()
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
