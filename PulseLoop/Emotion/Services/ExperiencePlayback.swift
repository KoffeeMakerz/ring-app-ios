import AVFoundation
import Foundation
import Observation

/// One feeling's stretch of the song in an experience session.
struct ExperiencePart: Identifiable, Hashable {
    let index: Int
    let feeling: Feeling
    let start: Double
    let end: Double
    var id: Int { index }
}

/// Plays an experience: music + slideshow, split into one part per feeling of its arc
/// (e.g. joy, then gratitude). At each cue marker the ring plays the touch of the part the cue
/// falls in. Cues are driven from the *playback position* (not a separate timer) so they never
/// drift from the chorus. Without a bundled audio file it runs on a silent clock.
@MainActor
@Observable
final class ExperiencePlayback {
    private(set) var track: MusicTrack
    let feelings: [Feeling]
    private(set) var position: Double = 0
    private(set) var isPlaying = false
    private(set) var lastCueIndex: Int? = nil
    private(set) var cueFiredAt: Date? = nil
    var slideCount: Int = 6
    var slideSeconds: Double = 8
    /// Mute switch for the ring during this session.
    var cuesEnabled = true
    /// Auto = fire at the song's cue markers; false = the person taps "replay cue" themselves.
    var autoCues = true
    private(set) var tapCount = 0
    /// Overrides the touch when the experience has a single feeling with a custom touch (v1 data).
    private let singleTouchOverride: TouchPattern?

    private let haptics: RingHapticsService
    private var player: AVAudioPlayer?
    private var tick: Task<Void, Never>?
    private var firedCues: Set<Int> = []

    init(track: MusicTrack, feelings: [Feeling], haptics: RingHapticsService, singleTouchOverride: TouchPattern? = nil) {
        self.track = track
        self.feelings = feelings.isEmpty ? [.gratitude] : feelings
        self.haptics = haptics
        self.singleTouchOverride = self.feelings.count == 1 ? singleTouchOverride : nil
        if let name = track.fileName, let url = Bundle.main.url(forResource: name, withExtension: nil) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        }
    }

    var duration: Double { player?.duration ?? Double(track.durationS) }
    var progress: Double { duration > 0 ? position / duration : 0 }
    var slideIndex: Int { slideCount > 0 ? Int(position / slideSeconds) % slideCount : 0 }
    var isInCue: Bool { cueFiredAt.map { Date().timeIntervalSince($0) < 2.5 } ?? false }
    var nextCueIndex: Int { track.cueMarkersS.firstIndex { Double($0) > position } ?? track.cueMarkersS.count }

    /// Equal parts of the song, one per feeling, in arc order.
    var parts: [ExperiencePart] {
        let n = Double(feelings.count)
        return feelings.enumerated().map { i, f in
            ExperiencePart(index: i, feeling: f, start: duration * Double(i) / n, end: duration * Double(i + 1) / n)
        }
    }
    var currentPart: ExperiencePart { part(at: position) }
    var currentFeeling: Feeling { currentPart.feeling }
    /// The touch for the part playing now.
    var touch: TouchPattern { touch(for: currentPart) }

    func part(at seconds: Double) -> ExperiencePart {
        parts.last { seconds >= $0.start } ?? parts[0]
    }
    func touch(for part: ExperiencePart) -> TouchPattern { singleTouchOverride ?? part.feeling.touch }
    func fraction(of part: ExperiencePart) -> Double {
        guard part.end > part.start else { return 0 }
        return min(1, max(0, (position - part.start) / (part.end - part.start)))
    }
    /// Feeling whose part contains cue marker `index`.
    func feeling(forCue index: Int) -> Feeling {
        guard track.cueMarkersS.indices.contains(index) else { return currentFeeling }
        return part(at: Double(track.cueMarkersS[index])).feeling
    }

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

    func seek(by seconds: Double) { seek(to: position + seconds) }

    func seek(to seconds: Double) {
        let wasPlaying = isPlaying
        pause()
        position = min(max(0, seconds), duration)
        // Don't re-fire cues already passed.
        firedCues = Set(track.cueMarkersS.indices.filter { Double(track.cueMarkersS[$0]) < position })
        if wasPlaying { play() }
    }

    func seekToPart(_ index: Int) {
        let all = parts
        guard all.indices.contains(index) else { return }
        seek(to: all[index].start)
    }

    func stop() {
        pause()
        haptics.stop(sendStop: false)
    }

    func playCueNow() {
        if !autoCues { tapCount += 1 }
        cueFiredAt = Date()
        haptics.play(touch)
    }

    private func checkCues() {
        guard cuesEnabled, autoCues else { return }
        for (i, marker) in track.cueMarkersS.enumerated() where !firedCues.contains(i) && position >= Double(marker) && position < Double(marker) + 2 {
            fire(index: i)
        }
    }

    private func fire(index: Int) {
        firedCues.insert(index)
        lastCueIndex = index
        cueFiredAt = Date()
        haptics.play(touch(for: part(at: Double(track.cueMarkersS[index]))))
    }

    private func finish() {
        pause()
        position = duration
    }
}
