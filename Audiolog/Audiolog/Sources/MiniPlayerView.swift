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

                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let duration = max(audioPlayer.totalDuration, 1)
                    let currentTime =
                        isScrubbing
                        ? scrubTime
                        : audioPlayer.currentPlaybackTime
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        let clampedCurrent = min(
                            max(currentTime, 0),
                            duration
                        )
                        let progress =
                            duration > 0 ? clampedCurrent / duration : 0

                        VStack {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(
                                    cornerRadius: 3,
                                    style: .continuous
                                )
                                .fill(.lbl3)
                                .frame(height: 7)

                                RoundedRectangle(
                                    cornerRadius: 3,
                                    style: .continuous
                                )
                                .fill(.lbl1)
                                .frame(
                                    width: max(
                                        0,
                                        min(width * progress, width)
                                    ),
                                    height: 7
                                )
                            }

                            Spacer()

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
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isScrubbing = true
                                    let x = min(
                                        max(0, value.location.x),
                                        width
                                    )
                                    let ratio = width > 0 ? x / width : 0
                                    let newTime = ratio * duration
                                    scrubTime = min(
                                        max(newTime, 0),
                                        duration
                                    )
                                }
                                .onEnded { value in
                                    let x = min(
                                        max(0, value.location.x),
                                        width
                                    )
                                    let ratio = width > 0 ? x / width : 0
                                    let newTime = ratio * duration
                                    scrubTime = min(
                                        max(newTime, 0),
                                        duration
                                    )
                                    isScrubbing = false
                                    audioPlayer.seek(to: scrubTime)
                                }
                        )
                    }
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
                        audioPlayer.skipBackward5()
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
                        audioPlayer.skipForward5()
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
    }

    private func formatTime(_ time: Double) -> String {
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
