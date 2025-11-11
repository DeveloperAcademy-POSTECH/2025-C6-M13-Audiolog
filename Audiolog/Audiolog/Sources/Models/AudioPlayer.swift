//
//  AudioPlayer.swift
//  Audiolog
//
//  Created by Sean Cho on 10/29/25.
//

import AVFoundation
import MediaPlayer
import SwiftUI

@Observable
@MainActor
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

    var current: Recording?
    var isPlaying: Bool = false
    var playlist: [Recording] = []
    var currentIndex: Int?
    var currentPlaybackTime: Double {
        player?.currentTime ?? 0
    }
    var rate: Float {
        player?.rate ?? 0
    }
    var totalDuration: Double {
        player?.duration ?? 0
    }

    var onRecordingFinished: (() -> Void)?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var commandsConfigured = false

    func setPlaylist(_ items: [Recording]) {
        playlist = items
        currentIndex = items.isEmpty ? nil : 0
    }

    func playFromStart() {
        guard !playlist.isEmpty else { return }
        currentIndex = 0
        let item = playlist[0]
        load(item)
        play()
    }

    func playNextInPlaylist() {
        guard !playlist.isEmpty else { return }
        let nextIndex: Int
        if let idx = currentIndex {
            nextIndex = idx + 1
        } else {
            nextIndex = 0
        }
        guard nextIndex < playlist.count else { return }
        currentIndex = nextIndex
        let item = playlist[nextIndex]
        load(item)
        play()
    }

    func playPreviousInPlaylist() {
        guard !playlist.isEmpty else { return }
        let previousIndex: Int
        if let idx = currentIndex {
            previousIndex = idx - 1
        } else {
            previousIndex = playlist.count - 1
        }
        guard previousIndex >= 0 && previousIndex < playlist.count else {
            return
        }
        currentIndex = previousIndex
        let item = playlist[previousIndex]
        load(item)
        play()
    }

    func load(_ recording: Recording) {
        let fileName = recording.fileName
        let documentURL = getDocumentURL()

        let fileURL = documentURL.appendingPathComponent(fileName)

        logger.log("Loading audio from: \(recording.fileName)")
        do {
            player = try AVAudioPlayer(contentsOf: fileURL)
            logger.log(
                "AVAudioPlayer initialized successfully for: \(fileURL.lastPathComponent)"
            )
        } catch {
            logger.error(
                "Failed to initialize AVAudioPlayer: \(String(describing: error))"
            )
            player = nil
        }
        player?.prepareToPlay()
        current = recording
    }

    func play() {
        player?.delegate = self
        let started = player?.play() ?? false

        // 잠금 화면 정보 업데이트 및 주기 갱신 시작
        if let current {
            updateNowPlayingInfo(recording: current)
        }
        if started { startNowPlayingUpdates() } else { stopNowPlayingUpdates() }
    }

    func pause() {
        player?.pause()
        stopNowPlayingUpdates()
        if let currentSong = current {
            updateNowPlayingInfo(recording: currentSong)
        }
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        stopNowPlayingUpdates()
        if let currentSong = current {
            updateNowPlayingInfo(recording: currentSong)
        }
    }

    func seek(to time: TimeInterval) {
        if let player {
            let clamped = max(0, min(time, player.duration))
            player.currentTime = clamped
        }
        if let current {
            updateNowPlayingInfo(recording: current)
        }
    }

    func togglePlayPause() {
        if player?.isPlaying == true {
            pause()
        } else {
            play()
        }
    }

    func skip(by delta: TimeInterval) {
        guard let player else { return }
        let duration = player.duration
        let newTime = max(0, min(player.currentTime + delta, duration))
        seek(to: newTime)
    }

    func skipForward5() {
        skip(by: 5)
    }

    func skipBackward5() {
        skip(by: -5)
    }

    func updateNowPlayingInfo(recording: Recording) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: recording.title,
            MPMediaItemPropertyArtist: "Audiolog",
            MPMediaItemPropertyPlaybackDuration: recording.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime
                ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: (player?.isPlaying == true)
                ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio
                .rawValue,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        if flag {
            stopNowPlayingUpdates()
            if let currentSong = current {
                updateNowPlayingInfo(recording: currentSong)
            }
            if let idx = currentIndex {
                let next = idx + 1
                if next < playlist.count {
                    currentIndex = next
                    let item = playlist[next]
                    load(item)
                    play()
                    return
                }
            }
            onRecordingFinished?()
        } else {
        }
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
        }
    }

    private func startNowPlayingUpdates() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            guard let self, let current = self.current else { return }
            self.updateNowPlayingInfo(recording: current)
        }
        isPlaying = true
    }

    private func stopNowPlayingUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
        isPlaying = false
    }

    private func setupRemoteCommands() {
        guard !commandsConfigured else { return }
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandsConfigured = true
    }
}
