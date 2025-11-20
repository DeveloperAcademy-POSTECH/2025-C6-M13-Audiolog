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
        VStack(spacing: 10) {
            if let current = audioPlayer.current {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(current.title == "" ? "제목 생성중" : current.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.lbl1)
                            .lineLimit(1)

                        if let createdAt = audioPlayer.current?.createdAt {
                            Text(createdAt.formatted("M월 d일 EEEE"))
                                .font(.footnote)
                                .foregroundColor(.lbl3)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                HStack(spacing: 5) {
                    Text(formatTime(audioPlayer.currentPlaybackTime))

                    Slider(
                        value:
                            Binding(
                                get: { audioPlayer.currentPlaybackTime },
                                set: { value in
                                    audioPlayer.seek(to: value)
                                }
                            ),
                        in: 0...audioPlayer.currentDuration,
                    )
                    .tint(.lbl1)

                    Text(formatTime(audioPlayer.currentDuration))
                }
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.lbl3)
                .padding(.horizontal, 20)

                HStack(spacing: 50) {
                    Button {
                        audioPlayer.playPreviousInPlaylist()
                    } label: {
                        Image(systemName: "backward.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 31, height: 31)
                    }

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(
                            systemName: audioPlayer.isPlaying
                                ? "pause.fill"
                                : "play.fill"
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 31, height: 31)
                    }

                    Button {
                        audioPlayer.playNextInPlaylist()
                    } label: {
                        Image(systemName: "forward.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 31, height: 31)
                    }
                }
                .tint(.lbl1)
                .padding(.top, 10)
                .padding(.bottom, 20)
            } else {
                HStack(alignment: .center) {
                    Text("재생 중이 아님")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.lbl2)

                    Spacer()

                    Image(
                        systemName: "play.fill"
                    )
                    .font(.system(size: 17))
                    .foregroundStyle(.lbl2)
                }
                .padding(.horizontal, 20)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
            }
        }
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
