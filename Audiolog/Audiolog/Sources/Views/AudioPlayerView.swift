//
//  AudioPlayerView.swift
//  Audiolog
//
//  Created by Sean Cho on 10/31/25.
//

import SwiftUI

struct AudioPlayerView: View {
    @Environment(AudioPlayer.self) private var audioPlayer
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0

    var body: some View {
        if let current = audioPlayer.current {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Spacer()
                    if let createdAt = audioPlayer.current?.createdAt {
                        Text(createdAt.formatted("M월 d일 EEEE"))
                            .font(.body.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(height: 44)

                Spacer().frame(height: 20)

                if audioPlayer.playlist != [] {
                    VStack(spacing: 30) {
                        HStack {
                            Button {
                                audioPlayer.playPreviousInPlaylist()
                            } label: {
                                Image(systemName: "arrowtriangle.backward.fill")
                                    .imageScale(.large)
                                    .font(.title3)
                            }
                            Spacer()

                            Text(
                                "\(audioPlayer.currentIndex ?? 0 + 1) / \(audioPlayer.playlist.count)"
                            )

                            Spacer()
                            Button {
                                audioPlayer.playNextInPlaylist()
                            } label: {
                                Image(systemName: "arrowtriangle.forward.fill")
                                    .imageScale(.large)
                                    .font(.title3)
                            }

                        }
                        .frame(height: 52)
                        .padding(.horizontal, 20)

                        Title3(text: current.title)
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        VStack(spacing: 8) {
                            let duration = max(audioPlayer.totalDuration, 1)
                            let currentTime =
                                isScrubbing
                                ? scrubTime : audioPlayer.currentPlaybackTime

                            Slider(
                                value: Binding(
                                    get: { min(max(currentTime, 0), duration) },
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
                                Text(Self.formatTime(currentTime))
                                Spacer()
                                Text(Self.formatTime(duration))
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 70)

                    HStack {
                        Button {
                            audioPlayer.skipBackward5()
                        } label: {
                            Image(systemName: "gobackward.5")
                                .imageScale(.large)
                                .font(.title3)
                        }

                        Spacer()

                        Button {
                            audioPlayer.togglePlayPause()
                        } label: {
                            Image(
                                systemName: audioPlayer.isPlaying
                                    ? "pause.circle.fill" : "play.circle.fill"
                            )
                            .font(.system(size: 44, weight: .regular))
                        }

                        Spacer()

                        Button {
                            audioPlayer.skipForward5()
                        } label: {
                            Image(systemName: "goforward.5")
                                .imageScale(.large)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 70)
                }
                .padding(.bottom, 62)
            }
            .animation(.default, value: audioPlayer.current?.id)
            .animation(.default, value: audioPlayer.isPlaying)
            .tint(.primary)
        }
    }

    private static func formatTime(_ time: Double) -> String {
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
