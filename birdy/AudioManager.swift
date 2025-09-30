import Foundation
import AVFoundation
import Combine
import SwiftUI

final class AudioManager: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var activeIsA: Bool = true
    private var timer: Timer?
    private var fadeTimer: Timer?
    private var scheduledCrossfadeTimer: Timer?

    private var fadeInDuration: TimeInterval
    private var fadeOutDuration: TimeInterval
    private let loop: Bool
    private var fileURL: URL?
    private var dipVolume: Float = 0.2

    /// Create an AudioManager for a bundled audio file.
    /// - Parameters:
    ///   - filename: resource name without extension
    ///   - fileExtension: file extension, default "m4a"
    ///   - autoplay: whether to start playback immediately
    ///   - loop: whether playback should loop indefinitely
    ///   - fadeInDuration: seconds to fade volume from 0 -> 1 at start
    ///   - fadeOutDuration: seconds to fade volume from 1 -> 0 at the end
    init(filename: String,
         fileExtension: String = "m4a",
         autoplay: Bool = false,
         loop: Bool = false,
         fadeInDuration: TimeInterval = 0,
         fadeOutDuration: TimeInterval = 0) {
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.loop = loop

        preparePlayers(filename: filename, fileExtension: fileExtension)
        if autoplay { play() }
    }
    private func preparePlayers(filename: String, fileExtension: String) {
        guard let url = Bundle.main.url(forResource: filename, withExtension: fileExtension) else {
            print("Audio file not found in bundle: \(filename).\(fileExtension)")
            return
        }

        fileURL = url

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            playerA = try AVAudioPlayer(contentsOf: url)
            playerB = try AVAudioPlayer(contentsOf: url)
            playerA?.prepareToPlay()
            playerB?.prepareToPlay()
            duration = playerA?.duration ?? playerB?.duration ?? 0
        } catch {
            print("AudioManager error: \(error)")
        }
    }

    func play() {
        guard let playerA = playerA, let playerB = playerB else { return }

        // activeIsA determines which player is currently playing
        activeIsA = true

        // Ensure players start at beginning
        playerA.currentTime = 0
        playerB.currentTime = 0

        // Set initial volumes
        if fadeInDuration > 0 {
            playerA.volume = 0
            playerB.volume = 0
        } else {
            playerA.volume = 1.0
            playerB.volume = 1.0
        }

        // Configure looping behavior: we'll handle looping manually via crossfade when loop=true
        playerA.numberOfLoops = 0
        playerB.numberOfLoops = 0

        // Start playerA
        playerA.play()
        isPlaying = true
        startTimer()

        if fadeInDuration > 0 {
            startFadeIn(for: playerA)
        }

        // If looping requested, schedule crossfades repeatedly
        scheduledCrossfadeTimer?.invalidate()
        scheduledCrossfadeTimer = nil
        if loop && fadeOutDuration > 0 {
            scheduleCrossfade(for: playerA)
        }
    }

    /// Fade out and stop playback. If `duration` is provided it will be used for the fade-out length.
    public func stopWithFadeOut(duration: TimeInterval? = nil) {
        if let d = duration {
            fadeOutDuration = d
        }
        // Cancel any scheduled fade timers to avoid double-calling
        scheduledCrossfadeTimer?.invalidate()
        scheduledCrossfadeTimer = nil
        startFadeOutForActivePlayer()
    }

    func pause() {
        playerA?.pause()
        playerB?.pause()
        isPlaying = false
        stopTimer()
        invalidateFadeTimers()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        playerA?.currentTime = time
        playerB?.currentTime = time
        currentTime = time
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.activeIsA, let p = self.playerA {
                    self.currentTime = p.currentTime
                    self.isPlaying = p.isPlaying
                } else if let p = self.playerB {
                    self.currentTime = p.currentTime
                    self.isPlaying = p.isPlaying
                }
            }
        }
    }
    private func startFadeIn(for player: AVAudioPlayer, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard fadeInDuration > 0 else { player.volume = 1.0; completion?(); return }

        let interval: TimeInterval = 0.05
        let steps = max(1, Int(fadeInDuration / interval))
        let increment = 1.0 / Double(steps)
        player.volume = 0

        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            currentStep += 1
            let newVolume = min(1.0, player.volume + Float(increment))
            player.volume = newVolume
            if currentStep >= steps {
                t.invalidate()
                self.fadeTimer = nil
                player.volume = 1.0
                completion?()
            }
        }
    }

    /// Fade `player` toward `targetVolume` (0.0..1.0). If `stopAtEnd` is true and targetVolume == 0, the player stops at the end.
    private func startFade(to targetVolume: Float, for player: AVAudioPlayer, stopAtEnd: Bool = false, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        guard fadeOutDuration > 0 else {
            player.volume = targetVolume
            if stopAtEnd && targetVolume <= 0.0 { player.stop() }
            completion?()
            return
        }

        let interval: TimeInterval = 0.05
        let steps = max(1, Int(fadeOutDuration / interval))
        let diff = Double(targetVolume - player.volume)
        let stepChange = diff / Double(steps)

        var currentStep = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            currentStep += 1
            let newVolume = max(0.0, min(1.0, Float(Double(player.volume) + stepChange)))
            player.volume = newVolume
            if currentStep >= steps {
                t.invalidate()
                self.fadeTimer = nil
                player.volume = targetVolume
                if stopAtEnd && targetVolume <= 0.0 { player.stop() }
                completion?()
            }
        }
    }

    private func startFadeOutForActivePlayer() {
        if activeIsA, let p = playerA { startFade(to: 0.0, for: p, stopAtEnd: true) } else if let p = playerB { startFade(to: 0.0, for: p, stopAtEnd: true) }
    }

    private func scheduleCrossfade(for currentPlayer: AVAudioPlayer) {
        scheduledCrossfadeTimer?.invalidate()
        scheduledCrossfadeTimer = nil

        let remaining = max(0, (currentPlayer.duration - currentPlayer.currentTime) - fadeOutDuration)
        scheduledCrossfadeTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.performCrossfade()
        }
    }

    private func performCrossfade() {
        guard let pA = playerA, let pB = playerB else { return }

        // Determine outgoing and incoming players
        let outgoing = activeIsA ? pA : pB
        let incoming = activeIsA ? pB : pA

        // Start incoming at beginning, volume 0
        incoming.currentTime = 0
        incoming.volume = 0
        incoming.play()

        // Soft-dip: fade outgoing to dipVolume (not zero), while incoming fades in to 1.0
        startFade(to: dipVolume, for: outgoing, stopAtEnd: false)
        startFadeIn(for: incoming) { [weak self] in
            guard let self = self else { return }
            // Stop outgoing after incoming fully faded in
            outgoing.stop()
            // switch active player
            self.activeIsA.toggle()
            // schedule next crossfade for the new active player
            let activePlayer = self.activeIsA ? self.playerA : self.playerB
            if let ap = activePlayer, self.loop {
                self.scheduleCrossfade(for: ap)
            }
        }
    }

    private func invalidateFadeTimers() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        scheduledFadeOutTimer?.invalidate()
        scheduledFadeOutTimer = nil
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
