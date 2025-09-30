import Foundation
import AVFoundation
import Combine
import SwiftUI

final class AudioManager: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// Create an AudioManager for a bundled audio file.
    /// - Parameters:
    ///   - filename: resource name without extension
    ///   - fileExtension: file extension, default "m4a"
    ///   - autoplay: whether to start playback immediately
    init(filename: String, fileExtension: String = "m4a", autoplay: Bool = false) {
        preparePlayer(filename: filename, fileExtension: fileExtension)
        if autoplay { play() }
    }

    private func preparePlayer(filename: String, fileExtension: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: fileExtension) else {
            print("Audio file not found in bundle: \(filename).\(fileExtension)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("AudioManager error: \(error)")
        }
    }

    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = player.currentTime
                self.isPlaying = player.isPlaying
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stopTimer()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
