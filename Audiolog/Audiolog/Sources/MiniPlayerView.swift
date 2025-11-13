//
//  MiniPlayerView.swift
//  Audiolog
//
//  Created by Sean Cho on 11/6/25.
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            if let current = audioPlayer.current {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(current.title == "" ? "제목 생성중" : current.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.lbl1)

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
                .padding(.bottom, 14)

                let duration = max(audioPlayer.audioLengthSeconds, 1)
                let currentTime =
                    isScrubbing ? scrubTime : audioPlayer.currentPlaybackTime

                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { currentTime },
                            set: { newValue in
                                let clamped = min(max(newValue, 0), duration)
                                scrubTime = clamped
                            }
                        ),
                        in: 0...duration,
                        onEditingChanged: { editing in
                            if editing {
                                DispatchQueue.main.async {
                                    isScrubbing = true
                                    scrubTime = audioPlayer.currentPlaybackTime
                                }
                            } else {
                                DispatchQueue.main.async {
                                    isScrubbing = false
                                }
                            }
                        }
                    )
                    .tint(.lbl1)
                    .onChange(of: isScrubbing) { _, newValue in
                        if newValue == false {
                            audioPlayer.seek(to: scrubTime)
                        }
                    }

                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.lbl3)
                }
                .frame(height: 28)
                .padding(.horizontal, 20)

                HStack(spacing: 30) {
                    Button {
                        audioPlayer.playPreviousInPlaylist()
                    } label: {
                        Image(systemName: "backward.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 31, height: 31)
                    }

                    Button {
                        audioPlayer.skip(forwards: false)
                    } label: {
                        Image(systemName: "gobackward.5")
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
                        audioPlayer.skip(forwards: true)
                    } label: {
                        Image(systemName: "goforward.5")
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
                .padding(.top, 15)
                .padding(.bottom, 17)
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
