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

    /// Key (bird card id) of the clip currently playing, if any.
    private(set) var currentKey: String?

    func toggle(url: URL, key: String) {
        if currentKey == key {
            stop()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        currentKey = key
        endWatcher = Task { [weak self] in
            let finished = NotificationCenter.default.notifications(
                named: AVPlayerItem.didPlayToEndTimeNotification, object: item)
            for await _ in finished.map({ _ in () }) {
                self?.stop()
                break
            }
        }
        player?.play()
    }

    func stop() {
        endWatcher?.cancel()
        endWatcher = nil
        player?.pause()
        player = nil
        currentKey = nil
    }
}
