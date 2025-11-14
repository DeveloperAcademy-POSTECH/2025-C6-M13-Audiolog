//
//  AudioPlayer.swift
//  Audiolog
//
//  Created by Sean Cho on 10/29/25.
//

import AVFoundation
import MediaPlayer
import SwiftUI

// swiftlint:disable:next type_body_length
@Observable
@MainActor
class AudioPlayer: NSObject {
    var current: Recording?
    var playlist: [Recording] = []
    var currentIndex: Int?

    var isPlaying = false
    var isPlayerReady = false
    var playbackRateIndex: Int = 1 {
        didSet {
            updateForRateSelection()
        }
    }
    var playerProgress: Double = 0
    var currentPlaybackTime: Double = 0
    var audioLengthSeconds: Double = 0

    let allPlaybackRates: [PlaybackValue] = [
        .init(value: 0.5, label: "0.5x"),
        .init(value: 1, label: "1x"),
        .init(value: 1.25, label: "1.25x"),
        .init(value: 2, label: "2x"),
    ]

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timeEffect = AVAudioUnitTimePitch()
    private var isTapInstalled = false
    private var isEngineConfigured = false

    private var displayLink: CADisplayLink?

    private var needsFileScheduled = true

    private var audioFile: AVAudioFile?
    private var audioSampleRate: Double = 0

    private var seekFrame: AVAudioFramePosition = 0
    private var currentPosition: AVAudioFramePosition = 0
    private var audioLengthSamples: AVAudioFramePosition = 0

    private var currentFrame: AVAudioFramePosition {
        guard
            let lastRenderTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: lastRenderTime)
        else {
            return 0
        }

        return playerTime.sampleTime
    }

    override init() {
        super.init()
        setupAudioSession()
        setupDisplayLink()
        remoteCommandCenterSetting()
    }

    func play() {
        displayLink?.isPaused = false
        connectVolumeTap()

        if needsFileScheduled {
            logger.log(
                "needsFileScheduled == true, calling scheduleAudioFile()"
            )
            scheduleAudioFile()
        } else {
            logger.log(
                "needsFileScheduled == false, NOT calling scheduleAudioFile()"
            )
        }

        player.play()
        logger.log(
            "player.play() called. player.isPlaying(after) = \(player.isPlaying)"
        )

        isPlaying = player.isPlaying
    }

    func pause() {
        logger.log("player.isPlaying is true -> will pause()")
        displayLink?.isPaused = true
        disconnectVolumeTap()

        player.pause()
        logger.log(
            "player.pause() called. player.isPlaying(after) = \(player.isPlaying)"
        )

        isPlaying = player.isPlaying
    }

    func togglePlayPause() {
        if player.isPlaying {
            pause()
        } else {
            play()
        }
    }

    func skip(forwards: Bool) {
        let timeToSeek: Double

        if forwards {
            timeToSeek = 5
        } else {
            timeToSeek = -5
        }

        seek(to: timeToSeek, isSkip: true)
    }

    func setPlaylist(_ items: [Recording]) {
        playlist = items
        currentIndex = items.isEmpty ? nil : 0
    }

    func playFromStart() {
        guard !playlist.isEmpty else { return }
        playItem(at: 0)
    }

    func playNextInPlaylist() {
        guard !playlist.isEmpty else { return }

        if let index = currentIndex {
            let nextIndex = index + 1
            guard playlist.indices.contains(nextIndex) else { return }
            playItem(at: nextIndex, playNow: false)
        } else {
            playFromStart()
        }
    }

    func playPreviousInPlaylist() {
        guard !playlist.isEmpty else { return }

        if let index = currentIndex {
            let previousIndex = index - 1
            guard playlist.indices.contains(previousIndex) else { return }
            playItem(at: previousIndex, playNow: false)
        } else {
            playFromStart()
        }
    }

    func load(_ recording: Recording) {
        logger.log("load() called")

        resetForNewFile()

        let fileName = recording.fileName
        let documentURL = getDocumentURL()

        let fileURL = documentURL.appendingPathComponent(fileName)

        logger.log("Found mp4 at URL: \(fileURL)")

        do {
            let file = try AVAudioFile(forReading: fileURL)
            let format = file.processingFormat

            logger.log("AVAudioFile created")
            logger.log("sampleRate: \(format.sampleRate)")
            logger.log("channelCount: \(format.channelCount)")
            logger.log("length (frames): \(file.length)")

            audioLengthSamples = file.length
            audioSampleRate = format.sampleRate
            audioLengthSeconds = Double(audioLengthSamples) / audioSampleRate

            logger.log("audioSampleRate set to \(audioSampleRate)")
            logger.log("audioLengthSamples set to \(audioLengthSamples)")
            logger.log("audioLengthSeconds computed as \(audioLengthSeconds)")

            audioFile = file

            configureEngine(with: format)

            current = recording

            if let idx = playlist.firstIndex(where: { $0.id == recording.id }) {
                currentIndex = idx
            } else {
                currentIndex = nil
            }
        } catch {
            logger.log("Error reading the audio file: \(error)")
            logger.log("localizedDescription: \(error.localizedDescription)")
        }
    }

    private func playItem(at index: Int, playNow: Bool = true) {
        guard playlist.indices.contains(index) else { return }

        let item = playlist[index]
        currentIndex = index
        load(item)
        updateNowPlayingInfo(current: item)
        
        if playNow || isPlaying {
            play()
        }
    }

    private func configureEngine(with format: AVAudioFormat) {
        logger.log("configureEngine() called")
        logger.log(
            "format.sampleRate = \(format.sampleRate), channels = \(format.channelCount)"
        )

        if isEngineConfigured {
            logger.log("engine already configured, scheduling new file only")
            scheduleAudioFile()
            isPlayerReady = true
            return
        }

        engine.attach(player)
        engine.attach(timeEffect)
        logger.log("Attached player and timeEffect to engine")

        engine.connect(
            player,
            to: timeEffect,
            format: format
        )
        engine.connect(
            timeEffect,
            to: engine.mainMixerNode,
            format: format
        )

        logger.log("Connected nodes: player -> timeEffect -> mainMixerNode")

        engine.prepare()
        logger.log("engine.prepare() called, starting engine...")

        do {
            try engine.start()
            logger.log("engine.start() succeeded")

            scheduleAudioFile()
            isPlayerReady = true
            isEngineConfigured = true
            logger.log(
                "scheduleAudioFile() called and isPlayerReady set to true"
            )
        } catch {
            logger.log("Error starting the engine/player: \(error)")
            logger.log("localizedDescription: \(error.localizedDescription)")
        }
    }

    private func scheduleAudioFile() {
        logger.log(
            "scheduleAudioFile() called. needsFileScheduled = \(needsFileScheduled)"
        )

        guard let file = audioFile else {
            logger.log("scheduleAudioFile(): audioFile is nil")
            return
        }

        guard needsFileScheduled else {
            logger.log(
                "scheduleAudioFile(): needsFileScheduled is false, skipping scheduling"
            )
            return
        }

        needsFileScheduled = false
        seekFrame = 0

        logger.log(
            "Scheduling file from frame 0. audioLengthSamples = \(audioLengthSamples)"
        )

        player.scheduleFile(file, at: nil) { [weak self] in
            guard let self else { return }
            logger.log(
                "scheduleFile completion handler fired (playback completed). Setting needsFileScheduled = true"
            )
            Task { @MainActor in
                self.needsFileScheduled = true
            }
        }
    }

    // MARK: Audio adjustments

    func seek(to time: Double, isSkip: Bool = false) {
        logger.log("seek(to: \(time)) called")

        guard let audioFile = audioFile else {
            logger.log("seek aborted: audioFile is nil")
            return
        }

        logger.log(
            "currentPosition(before) = \(currentPosition), seekFrame(before) = \(seekFrame)"
        )
        logger.log("audioSampleRate = \(audioSampleRate)")

        let offset = AVAudioFramePosition(time * audioSampleRate)
        logger.log("computed offset (frames) = \(offset)")

        seekFrame = isSkip ? currentPosition + offset : offset
        seekFrame = max(seekFrame, 0)
        seekFrame = min(seekFrame, audioLengthSamples)
        currentPosition = seekFrame

        logger.log(
            "clamped seekFrame = \(seekFrame), new currentPosition = \(currentPosition) / \(audioLengthSamples)"
        )

        let wasPlaying = player.isPlaying
        logger.log("wasPlaying(before stop) = \(wasPlaying)")
        player.stop()
        logger.log("player.stop() called")

        if currentPosition < audioLengthSamples {
            updateDisplay()
            needsFileScheduled = false

            let frameCount = AVAudioFrameCount(audioLengthSamples - seekFrame)
            logger.log(
                "scheduling segment from frame \(seekFrame), frameCount = \(frameCount)"
            )

            player.scheduleSegment(
                audioFile,
                startingFrame: seekFrame,
                frameCount: frameCount,
                at: nil
            ) {
                logger.log(
                    "scheduleSegment completion handler fired (segment finished). Setting needsFileScheduled = true"
                )
                Task { @MainActor in
                    self.needsFileScheduled = true
                }
            }

            if wasPlaying {
                player.play()
            }
        }
    }

    private func updateForRateSelection() {
        let selectedRate = allPlaybackRates[playbackRateIndex]
        timeEffect.rate = Float(selectedRate.value)
    }

    private func connectVolumeTap() {
        logger.log("connectVolumeTap() called")

        guard !isTapInstalled else {
            logger.log("connectVolumeTap() skipped: tap already installed")
            return
        }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        logger.log(
            "mainMixerNode outputFormat: sampleRate = \(format.sampleRate), channels = \(format.channelCount)"
        )

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { _, _ in
            // TODO: haptic추가 이쯤에서 하려나..
        }

        isTapInstalled = true
    }

    private func disconnectVolumeTap() {
        logger.log("disconnectVolumeTap() called")

        guard isTapInstalled else {
            logger.log("disconnectVolumeTap() skipped: no tap installed")
            return
        }

        engine.mainMixerNode.removeTap(onBus: 0)
        isTapInstalled = false
    }

    // MARK: Display updates
    private func setupDisplayLink() {
        logger.log("setupDisplayLink() called")
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateDisplay)
        )
        displayLink?.add(to: .current, forMode: .default)
        displayLink?.isPaused = true
        logger.log("displayLink created and initially paused")
    }

    @objc private func updateDisplay() {
        let oldPosition = currentPosition
        currentPosition = currentFrame + seekFrame
        currentPosition = max(currentPosition, 0)
        currentPosition = min(currentPosition, audioLengthSamples)

        if oldPosition != currentPosition {
            logger.log(
                "updateDisplay() currentPosition = \(currentPosition) / \(audioLengthSamples), seekFrame = \(seekFrame)"
            )
        }

        if currentPosition >= audioLengthSamples {
            logger.log("Reached end of audio. Stopping player.")
            player.stop()
            displayLink?.isPaused = true
            disconnectVolumeTap()

            if let index = currentIndex {
                let nextIndex = index + 1
                if playlist.indices.contains(nextIndex) {
                    logger.log(
                        "Moving to next item in playlist at index \(nextIndex)"
                    )
                    playItem(at: nextIndex)
                    return
                }
            }

            seekFrame = 0
            currentPosition = 0
            isPlaying = false
        }

        playerProgress = Double(currentPosition) / Double(audioLengthSamples)

        let time = Double(currentPosition) / audioSampleRate
        currentPlaybackTime = time

        if let current {
            updateNowPlayingInfo(current: current)
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowBluetoothHFP]
            )
            try session.setActive(true)
            logger.log(
                "AVAudioSession configured: category=\(session.category.rawValue), outputVolume=\(session.outputVolume)"
            )
        } catch {
            logger.log("AVAudioSession error: \(error)")
        }
    }

    private func resetForNewFile() {
        displayLink?.isPaused = true
        disconnectVolumeTap()
        player.stop()

        seekFrame = 0
        currentPosition = 0
        playerProgress = 0
        currentPlaybackTime = 0

        needsFileScheduled = true
    }

    private func updateNowPlayingInfo(current: Recording) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = current.title
        //        if let albumCoverPage = UIImage(named: String(substring) + "_icon") {
        //            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: albumCoverPage.size, requestHandler: { size in
        //                return albumCoverPage
        //            })
        //        }
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioLengthSeconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
            currentPlaybackTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func remoteCommandCenterSetting() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            self.play()
            return MPRemoteCommandHandlerStatus.success
        }

        center.pauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            self.pause()
            return MPRemoteCommandHandlerStatus.success
        }

        center.nextTrackCommand.addTarget {
            (_) -> MPRemoteCommandHandlerStatus in
            self.playNextInPlaylist()
            return MPRemoteCommandHandlerStatus.success
        }

        center.previousTrackCommand.addTarget {
            (_) -> MPRemoteCommandHandlerStatus in
            self.playPreviousInPlaylist()
            return MPRemoteCommandHandlerStatus.success
        }

        let changePositionCommand = center.changePlaybackPositionCommand
        changePositionCommand.isEnabled = true
        changePositionCommand.addTarget {
            event -> MPRemoteCommandHandlerStatus in
            guard
                let positionEvent = event
                    as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
}

struct PlaybackValue: Identifiable {
    let value: Double
    let label: String

    var id: String {
        return "\(label)-\(value)"
    }
}
