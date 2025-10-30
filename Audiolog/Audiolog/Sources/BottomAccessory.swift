//
//  BottomAccessory.swift
//  Audiolog
//
//  Created by Sean Cho on 10/30/25.
//

import SwiftUI

struct BottomAccessory: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    var body: some View {
        HStack(spacing: 10) {
            if let currentRecording = audioPlayer.current {
                Text(currentRecording.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
            } else {
                Text("재생 중이 아님")
                    .font(.footnote)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else {
                    audioPlayer.play()
                }
            } label: {
                Image(
                    systemName: audioPlayer.isPlaying
                        ? "stop.fill" : "play.fill"
                )
                .font(.footnote)
                .contentShape(Rectangle())
            }
        }
        .foregroundStyle(audioPlayer.current == nil ? .secondary : .primary)
        .tint(audioPlayer.current == nil ? .secondary : .primary)
        .padding(.horizontal, 20)
    }
}

#Preview {
    BottomAccessory()
}
