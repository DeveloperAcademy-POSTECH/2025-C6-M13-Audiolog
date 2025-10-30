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
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var current: Recording?
    private var progressTimer: Timer?
    private var commandsConfigured = false

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }

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

    func load(_ recording: Recording) {
        player = try? AVAudioPlayer(contentsOf: recording.fileURL)
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

    func updateNowPlayingInfo(recording: Recording) {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: recording.title,
            MPMediaItemPropertyArtist: "Audiolog",
            MPMediaItemPropertyPlaybackDuration: recording.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: (player?.isPlaying == true) ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        if flag {
            stopNowPlayingUpdates()
            if let currentSong = current { updateNowPlayingInfo(recording: currentSong) }
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
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let current = self.current else { return }
            self.updateNowPlayingInfo(recording: current)
        }
    }

    private func stopNowPlayingUpdates() {
        progressTimer?.invalidate()
        progressTimer = nil
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
