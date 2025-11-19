import AVFoundation
import Foundation
import MediaPlayer

@Observable
@MainActor
class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?

    private(set) var isPlaying: Bool = false

    var current: Recording?
    var playlist: [Recording] = []
    var currentIndex: Int?

    private(set) var currentPlaybackTime: Double = 0
    private(set) var currentPlaybackRate: Float = 0
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
        let fileName = recording.fileName
        let documentURL = getDocumentURL()
        let fileURL = documentURL.appendingPathComponent(fileName)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            current = recording

            if let index = playlist.firstIndex(where: { $0 == recording }) {
                currentIndex = index
            } else {
                currentIndex = nil
            }

            if let player = audioPlayer {
                currentDuration = player.duration
                currentPlaybackTime = player.currentTime
                currentPlaybackRate = player.rate
            }
        } catch {
            logger.log("[AudioPlayer] AVAudioPlayer 생성 실패함")
        }
    }

    func play() {
        audioPlayer?.delegate = self
        audioPlayer?.play()
        startPlaybackTimer()
        isPlaying = true

        updateNowPlayingInfo()
    }

    func pause() {
        audioPlayer?.pause()
        stopPlaybackTimer()
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
        guard let player = audioPlayer else { return }

        if time > currentDuration {
            player.currentTime = currentDuration
        } else if time < 0 {
            player.currentTime = 0
        } else {
            player.currentTime = time
        }

        currentPlaybackTime = player.currentTime
        updateNowPlayingInfo()
    }

    func skip(isForward: Bool) {
        if isForward {
            seek(to: currentPlaybackTime + 5)
        } else {
            seek(to: currentPlaybackTime - 5)
        }
    }

    func playPreviousInPlaylist() {
        guard !playlist.isEmpty else { return }
        let wasPlaying = isPlaying

        if currentPlaybackTime > 3 {
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
        audioPlayer?.stop()
        stopPlaybackTimer()
        isPlaying = false

        current = nil
        playlist = []
        currentIndex = nil
        currentDuration = 0
        currentPlaybackTime = 0
        currentPlaybackRate = 0

        updateNowPlayingInfo()
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        stopPlaybackTimer()
        isPlaying = false
        currentPlaybackRate = 0
        updateNowPlayingInfo()
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback)
        try? audioSession.setActive(true)
    }

    private func updateNowPlayingInfo() {
        guard let current else { return }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = current.title

        if let albumCoverPage = UIImage(named: "AppIcon") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                boundsSize: albumCoverPage.size,
                requestHandler: { _ in
                    return albumCoverPage
                }
            )
        }

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = current.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
            currentPlaybackTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()

        playbackTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            guard let self, let player = self.audioPlayer else {
                self?.stopPlaybackTimer()
                return
            }

            self.currentPlaybackTime = player.currentTime
            self.currentPlaybackRate = player.rate
            self.currentDuration = player.duration
        }

        RunLoop.main.add(playbackTimer!, forMode: .common)
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
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
