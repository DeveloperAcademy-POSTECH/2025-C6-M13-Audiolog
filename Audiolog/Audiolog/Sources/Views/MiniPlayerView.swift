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
        VStack {
            if let current = audioPlayer.current {
                Text(current.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)

                if let createdAt = audioPlayer.current?.createdAt {
                    Text(createdAt.formatted("M월 d일 EEEE"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    VStack(spacing: 8) {
                        let duration = max(audioPlayer.totalDuration, 1)
                        let currentTime =
                            isScrubbing
                            ? scrubTime
                            : audioPlayer.currentPlaybackTime

                        Slider(
                            value: Binding(
                                get: {
                                    min(max(currentTime, 0), duration)
                                },
                                set: { newValue in
                                    scrubTime = newValue
                                }
                            ),
                            in: 0...duration,
                            onEditingChanged: { editing in
                                isScrubbing = editing
                                if !editing {
                                    audioPlayer.seek(to: scrubTime)
                                }
                            }
                        )
                        HStack {
                            Text(formatTime(currentTime))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 70)
                HStack {
                    Button {
                        audioPlayer.playPreviousInPlaylist()
                    } label: {
                        Image(systemName: "arrowtriangle.backward.fill")
                            .imageScale(.large)
                            .font(.title3)
                    }

                    Button {
                        audioPlayer.skipBackward5()
                    } label: {
                        Image(systemName: "gobackward.5")
                            .imageScale(.large)
                            .font(.title3)
                    }

                    Button {
                        audioPlayer.togglePlayPause()
                    } label: {
                        Image(
                            systemName: audioPlayer.isPlaying
                                ? "pause.circle.fill"
                                : "play.circle.fill"
                        )
                        .font(.system(size: 44, weight: .regular))
                    }

                    Button {
                        audioPlayer.skipForward5()
                    } label: {
                        Image(systemName: "goforward.5")
                            .imageScale(.large)
                            .font(.title3)
                    }

                    Button {
                        audioPlayer.playNextInPlaylist()
                    } label: {
                        Image(systemName: "arrowtriangle.forward.fill")
                            .imageScale(.large)
                            .font(.title3)
                    }
                }
            } else {
                HStack {
                    Text("재생 중이 아님")
                        .font(.footnote)
                        .fontWeight(.semibold)

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
                .frame(maxWidth: .infinity)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 34))
    }

    private func formatTime(_ time: Double) -> String {
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
