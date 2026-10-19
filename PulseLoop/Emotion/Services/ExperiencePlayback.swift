import AVFoundation
import Foundation
import Observation

/// Plays an experience: music + slideshow, firing the ring touch at each cue marker.
/// Cues are driven from the *playback position* (not a separate timer) so they never drift from
/// the chorus. Without a bundled audio file it runs on a silent clock.
@MainActor
@Observable
final class ExperiencePlayback {
    private(set) var track: MusicTrack
    private(set) var touch: TouchPattern
    private(set) var position: Double = 0
    private(set) var isPlaying = false
    private(set) var lastCueIndex: Int? = nil
    private(set) var cueFiredAt: Date? = nil
    var slideCount: Int = 6
    var slideSeconds: Double = 8
    var cuesEnabled = true

    private let haptics: RingHapticsService
    private var player: AVAudioPlayer?
    private var tick: Task<Void, Never>?
    private var firedCues: Set<Int> = []

    init(track: MusicTrack, touch: TouchPattern, haptics: RingHapticsService) {
        self.track = track
        self.touch = touch
        self.haptics = haptics
        if let name = track.fileName, let url = Bundle.main.url(forResource: name, withExtension: nil) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        }
    }

    var duration: Double { player?.duration ?? Double(track.durationS) }
    var progress: Double { duration > 0 ? position / duration : 0 }
    var slideIndex: Int { slideCount > 0 ? Int(position / slideSeconds) % slideCount : 0 }
    var cueIndexNow: Int? { track.cueMarkersS.firstIndex { Double($0) <= position && position < Double($0) + 4 } }
    var isInCue: Bool { cueFiredAt.map { Date().timeIntervalSince($0) < 2.5 } ?? false }
    var nextCueIndex: Int { track.cueMarkersS.firstIndex { Double($0) > position } ?? track.cueMarkersS.count }

    func play() {
        guard !isPlaying else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.currentTime = position
        player?.play()
        isPlaying = true
        let startWall = Date()
        let startPos = position
        tick = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                if let player = self.player { self.position = player.currentTime }
                else { self.position = startPos + Date().timeIntervalSince(startWall) }
                self.checkCues()
                if self.position >= self.duration { self.finish(); return }
            }
        }
    }

    func pause() {
        tick?.cancel()
        player?.pause()
        isPlaying = false
    }

    func toggle() { isPlaying ? pause() : play() }

    func seek(by seconds: Double) {
        let wasPlaying = isPlaying
        pause()
        position = min(max(0, position + seconds), duration)
        // Don't re-fire cues already passed.
        firedCues = Set(track.cueMarkersS.indices.filter { Double(track.cueMarkersS[$0]) < position })
        if wasPlaying { play() }
    }

    func stop() {
        pause()
        haptics.stop(sendStop: false)
    }

    func playCueNow() { fire(index: lastCueIndex ?? 0) }

    private func checkCues() {
        guard cuesEnabled else { return }
        for (i, marker) in track.cueMarkersS.enumerated() where !firedCues.contains(i) && position >= Double(marker) && position < Double(marker) + 2 {
            fire(index: i)
        }
    }

    private func fire(index: Int) {
        firedCues.insert(index)
        lastCueIndex = index
        cueFiredAt = Date()
        haptics.play(touch)
    }

    private func finish() {
        pause()
        position = duration
    }
}
