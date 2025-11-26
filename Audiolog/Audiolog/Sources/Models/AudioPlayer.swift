import AVFoundation
import Combine
import Foundation
import MediaPlayer

@Observable
@MainActor
class AudioPlayer: NSObject {
    private var player: AVPlayer?
    private var timeObserverToken: Any?

    private(set) var isPlaying: Bool = false

    var current: Recording?
    var playlist: [Recording] = []
    var currentIndex: Int?

    private(set) var currentPlaybackTime: Double = 0
    private(set) var currentDuration: Double = 0

    override init() {
        super.init()
        remoteCommandCenterSetting()
        setupAudioSession()
    }

    func setPlaylist(_ recordings: [Recording]) {
        playlist = recordings
        currentIndex = recordings.isEmpty ? nil : 0
    }

    func load(_ recording: Recording) {
        removeTimeObserver()

        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        let playerItem = AVPlayerItem(url: fileURL)
        player = AVPlayer(playerItem: playerItem)
        current = recording

        if let index = playlist.firstIndex(where: { $0 == recording }) {
            currentIndex = index
        } else {
            currentIndex = nil
        }

        setupTimeObserver()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        updateNowPlayingInfo()
    }

    // MARK: - Controls
    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: Double) {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)

        updateNowPlayingInfo()
    }

    func skip(isForward: Bool) {
        guard let player = player else { return }
        let currentTime = player.currentTime().seconds
        let newTime = isForward ? currentTime + 5 : currentTime - 5
        seek(to: newTime)
    }

    func playPreviousInPlaylist() {
        guard !playlist.isEmpty else { return }
        let wasPlaying = isPlaying

        if let player = player, player.currentTime().seconds > 3 {
            seek(to: 0)
            return
        }

        if let index = currentIndex {
            let previous = index - 1
            guard playlist.indices.contains(previous) else { return }
            load(playlist[previous])
            if wasPlaying { play() }
        }

        updateNowPlayingInfo()
    }

    func playNextInPlaylist() {
        guard !playlist.isEmpty else { return }
        let wasPlaying = isPlaying

        if let index = currentIndex {
            let nextIndex = index + 1
            guard playlist.indices.contains(nextIndex) else { return }
            load(playlist[nextIndex])
            if wasPlaying { play() }
        }

        updateNowPlayingInfo()
    }

    func currentItemDeleted() {
        player?.pause()
        removeTimeObserver()
        player = nil

        isPlaying = false
        current = nil
        playlist = []
        currentIndex = nil
        currentDuration = 0
        currentPlaybackTime = 0

        updateNowPlayingInfo()
    }

    @objc private func playerDidFinishPlaying(note: NSNotification) {
        isPlaying = false
        updateNowPlayingInfo()
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            print("AudioSession 설정 실패: \(error)")
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }

            self.currentPlaybackTime = time.seconds

            if let duration = player.currentItem?.duration.seconds,
                duration.isFinite
            {
                self.currentDuration = duration
            }

            self.updateNowPlayingInfo()
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func updateNowPlayingInfo() {
        guard let current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = current.title

        if let albumCoverPage = UIImage(named: "AppIcon") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: albumCoverPage.size,
                requestHandler: { _ in return albumCoverPage }
            )
        }

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] =
            currentDuration.isFinite ? currentDuration : 0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
            currentPlaybackTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] =
            isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func remoteCommandCenterSetting() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextInPlaylist()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousInPlaylist()
            return .success
        }

        let changePositionCommand = center.changePlaybackPositionCommand
        changePositionCommand.isEnabled = true
        changePositionCommand.addTarget { [weak self] event in
            guard
                let positionEvent = event
                    as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }
}
