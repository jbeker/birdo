//
//  AudioPlayer.swift
//  birdo
//
//  Streams a detection's WAV clip; one clip at a time.
//

import AVFoundation
import Observation

@Observable
final class AudioPlayer {
    private var player: AVPlayer?
    private var endWatcher: Task<Void, Never>?
    private var timeObserver: Any?

    /// Key (bird card id) of the clip currently playing, if any.
    private(set) var currentKey: String?
    /// Playback position of the current clip, 0...1.
    private(set) var progress: Double = 0

    func toggle(url: URL, key: String) {
        if currentKey == key {
            stop()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        currentKey = key
        endWatcher = Task { [weak self] in
            let finished = NotificationCenter.default.notifications(
                named: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            for await _ in finished.map({ _ in () }) {
                self?.stop()
                break
            }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, let item = self.player?.currentItem else { return }
                let duration = item.duration.seconds
                guard duration.isFinite, duration > 0 else { return }
                self.progress = min(max(time.seconds / duration, 0), 1)
            }
        }
        player.play()
    }

    func stop() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        endWatcher?.cancel()
        endWatcher = nil
        player?.pause()
        player = nil
        currentKey = nil
        progress = 0
    }
}
