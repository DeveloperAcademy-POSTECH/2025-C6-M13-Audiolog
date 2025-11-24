//
//  MiniPlayerView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/6/25.
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayer.self) private var audioPlayer

    @State private var isSliderEditing: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let current = audioPlayer.current {
                VStack(alignment: .leading, spacing: 0) {
                    Text(current.title == "" ? "제목 생성중" : current.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.lbl1)
                        .lineLimit(1)
                        .padding(.top, 5)

                    HStack(spacing: 5) {
                        Text(formatTime(audioPlayer.currentPlaybackTime))

                        Slider(
                            value:
                                Binding(
                                    get: {
                                        audioPlayer.currentPlaybackTime
                                    },
                                    set: { value in
                                        audioPlayer.seek(to: value)
                                    }
                                ),
                            in: 0...audioPlayer.currentDuration,
                        )
                        .tint(.lbl1)

                        Text(formatTime(audioPlayer.currentDuration))
                    }
                    .frame(height: 24)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.lbl3)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("\(formatTime(audioPlayer.currentDuration)) 중 \(formatTime(audioPlayer.currentPlaybackTime))"))
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("재생 중이 아님")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.lbl2)
                        .lineLimit(1)
                        .padding(.top, 5)

                    HStack(spacing: 5) {
                        Text(formatTime(0))

                        Capsule()
                            .fill(.lbl2.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 6)

                        Text(formatTime(0))
                    }
                    .frame(height: 24)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.lbl3)
                    .accessibilityHidden(true)
                }
            }
            Spacer()
            Button {
                if audioPlayer.current != nil {
                    audioPlayer.togglePlayPause()
                }
            } label: {
                Image(
                    systemName: audioPlayer.isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
                .font(.title2)
                .frame(width: 39, height: 44)
            }
            .tint(audioPlayer.current == nil ? .lbl2 : .lbl1)
            .disabled(audioPlayer.current == nil)

            Button {
                audioPlayer.playNextInPlaylist()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .frame(width: 39, height: 44)
            }
            .tint(audioPlayer.playlist.isEmpty ? .lbl2 : .lbl1)
            .disabled(audioPlayer.playlist.isEmpty)
            .accessibilityLabel(Text("다음"))
        }
        .padding(.horizontal, 20)
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 34))
        .animation(.default, value: audioPlayer.isPlaying)
        .accessibilityAction(.magicTap) {
            audioPlayer.togglePlayPause()
        }
        .contentShape(Rectangle())
    }

    private func formatTime(_ time: Double) -> String {
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
