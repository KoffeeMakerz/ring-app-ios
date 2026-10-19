import SwiftUI

/// A ring vibration: alternating motor-on / motor-off durations, max 8 s.
/// Stored as `{"durations_ms":[…],"starts_with":"vibration"}`.
struct TouchPattern: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var durationsMs: [Int]
    var startsWithVibration: Bool = true

    static let maxDurationMs = 8_000

    var totalMs: Int { durationsMs.reduce(0, +) }
    func isOn(segment index: Int) -> Bool { (index % 2 == 0) == startsWithVibration }

    /// Motor-on segments as (startMs, lengthMs).
    var pulses: [(start: Int, length: Int)] {
        var t = 0
        var result: [(Int, Int)] = []
        for (i, d) in durationsMs.enumerated() {
            if isOn(segment: i) { result.append((t, d)) }
            t += d
        }
        return result
    }

    var json: String {
        let list = durationsMs.map(String.init).joined(separator: ",")
        return "{\"durations_ms\":[\(list)],\"starts_with\":\"\(startsWithVibration ? "vibration" : "pause")\"}"
    }
}

/// Building blocks for the optional composer and the "simple alerts" in the touch picker.
enum TouchBlock: String, CaseIterable, Identifiable, Codable {
    case tap, doubleTap, flutter, heartbeat, longHum, signal, shortRest, longRest
    var id: String { rawValue }

    var name: String {
        switch self {
        case .tap: "Tap"
        case .doubleTap: "Double tap"
        case .flutter: "Flutter"
        case .heartbeat: "Heartbeat"
        case .longHum: "Long hum"
        case .signal: "Signal"
        case .shortRest: "Short rest"
        case .longRest: "Long rest"
        }
    }
    var hint: String {
        switch self {
        case .tap: "a gentle hello"
        case .doubleTap: "notice this"
        case .flutter: "light, joyful"
        case .heartbeat: "warmth, love"
        case .longHum: "settle, ground"
        case .signal: "rise, wake up"
        case .shortRest, .longRest: "space"
        }
    }
    var isRest: Bool { self == .shortRest || self == .longRest }
    /// Alternating on/off ms, starting with motor-on (rests are a single off segment).
    var segments: [Int] {
        switch self {
        case .tap: [300]
        case .doubleTap: [200, 150, 200]
        case .flutter: [120, 100, 120, 100, 120]
        case .heartbeat: [150, 150, 350]
        case .longHum: [800]
        case .signal: [150, 100, 150, 100, 150, 300, 450, 150, 450, 150, 450]
        case .shortRest: [400]
        case .longRest: [1000]
        }
    }
    static let touches: [TouchBlock] = [.tap, .doubleTap, .flutter, .heartbeat, .longHum, .signal]
    static let rests: [TouchBlock] = [.shortRest, .longRest]

    /// Gap inserted automatically between two touch blocks so they are felt separately.
    static let autoGapMs = 250

    /// Flatten a block sequence into one pattern (merging adjacent off segments).
    static func compose(_ blocks: [TouchBlock], id: String = UUID().uuidString, name: String = "My touch") -> TouchPattern {
        var segs: [Int] = []   // alternating, index 0 = on
        func appendOff(_ ms: Int) {
            if segs.isEmpty { return } // never start with silence
            if segs.count % 2 == 0 { segs[segs.count - 1] += ms } else { segs.append(ms) }
        }
        func appendOn(_ ms: Int) {
            if segs.count % 2 == 1 { segs[segs.count - 1] += ms } else { segs.append(ms) }
        }
        var previous: TouchBlock?
        for block in blocks {
            if block.isRest {
                appendOff(block.segments[0])
            } else {
                if let previous, !previous.isRest { appendOff(autoGapMs) }
                for (i, ms) in block.segments.enumerated() { i % 2 == 0 ? appendOn(ms) : appendOff(ms) }
            }
            previous = block
        }
        // Drop a trailing rest.
        if segs.count % 2 == 0, !segs.isEmpty { segs.removeLast() }
        return TouchPattern(id: id, name: name, durationsMs: segs)
    }

    static func totalMs(_ blocks: [TouchBlock]) -> Int {
        var total = 0
        var previous: TouchBlock?
        for b in blocks {
            if !b.isRest, let previous, !previous.isRest { total += autoGapMs }
            total += b.segments.reduce(0, +)
            previous = b
        }
        return total
    }

    var pattern: TouchPattern { TouchBlock.compose([self], id: "alert.\(rawValue)", name: name) }
}

/// The trained feelings. Each feeling owns its ring touch.
enum Feeling: String, CaseIterable, Identifiable, Codable {
    case gratitude, love, joy, bliss, calm, confidence
    var id: String { rawValue }

    var name: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .gratitude: Color(hex: "#F2B45A")
        case .love: Color(hex: "#F27A9B")
        case .joy: Color(hex: "#F5D76E")
        case .bliss: Color(hex: "#B892FF")
        case .calm: Color(hex: "#7FB2F0")
        case .confidence: Color(hex: "#6FD6A1")
        }
    }
    /// Dark tinted ground used behind cards for this feeling.
    var ground: Color {
        switch self {
        case .gratitude: Color(hex: "#2A1E10")
        case .love: Color(hex: "#2E1420")
        case .joy: Color(hex: "#2B2612")
        case .bliss: Color(hex: "#221A33")
        case .calm: Color(hex: "#15233A")
        case .confidence: Color(hex: "#14291F")
        }
    }
    var rhythmDescription: String {
        switch self {
        case .gratitude: "Two, pause, one"
        case .love: "A heartbeat, twice"
        case .joy: "Two quick flutters"
        case .bliss: "Five rising taps"
        case .calm: "Two slow hums"
        case .confidence: "One, then two"
        }
    }
    var blocks: [TouchBlock] {
        switch self {
        case .gratitude: [.doubleTap, .shortRest, .tap]
        case .love: [.heartbeat, .shortRest, .heartbeat]
        case .joy: [.flutter, .shortRest, .flutter]
        case .bliss: [.flutter, .doubleTap]
        case .calm: [.longHum, .longRest, .longHum]
        case .confidence: [.tap, .shortRest, .doubleTap]
        }
    }
    var touch: TouchPattern { TouchBlock.compose(blocks, id: "feeling.\(rawValue)", name: "\(name) touch") }

    var intention: String {
        switch self {
        case .gratitude: "I notice what is already good, and say thank you."
        case .love: "I give and receive love easily."
        case .joy: "Joy is my natural state."
        case .bliss: "I let myself feel fully alive."
        case .calm: "I am safe, steady and at ease."
        case .confidence: "I trust myself and act with ease."
        }
    }
    var trainingPrompt: String {
        switch self {
        case .gratitude: "Think of someone who made this week easier. Let the thanks fill your chest."
        case .love: "Picture someone you love smiling at you. Let the warmth spread."
        case .joy: "Remember a moment you laughed until it hurt. Feel it again."
        case .bliss: "Imagine your vision already real. Let the excitement rise."
        case .calm: "Let your shoulders drop. Breathe out slowly and soften."
        case .confidence: "Recall a time you did something hard and it worked. Stand in it."
        }
    }
    var cuePrompt: String {
        switch self {
        case .gratitude: "Take one slow breath. What are you thankful for right now?"
        case .love: "Take one slow breath. Who do you love right now?"
        case .joy: "Take one slow breath. What made you smile today?"
        case .bliss: "Take one slow breath. Picture your vision, already true."
        case .calm: "Breathe out slowly. Let everything soften for a moment."
        case .confidence: "Stand tall for one breath. You've got this."
        }
    }
    /// Feelings unlock in this order (4 sessions of the previous one).
    static let unlockOrder: [Feeling] = [.gratitude, .love, .joy, .confidence, .bliss, .calm]
    static let sessionsToUnlockNext = 4
    static let programmeLength = 7
}

/// Music themes for the curated library.
enum MusicTheme: String, CaseIterable, Identifiable {
    case abundance, love, business, health, joy, gratitude
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .abundance: Color(hex: "#6FD6A1")
        case .love: Color(hex: "#F27A9B")
        case .business: Color(hex: "#B892FF")
        case .health: Color(hex: "#7FB2F0")
        case .joy: Color(hex: "#F5D76E")
        case .gratitude: Color(hex: "#F2B45A")
        }
    }
    var art: Color {
        switch self {
        case .abundance: Color(hex: "#1E3A2C")
        case .love: Color(hex: "#3F1C28")
        case .business: Color(hex: "#2D2245")
        case .health: Color(hex: "#1C2B40")
        case .joy: Color(hex: "#3D3418")
        case .gratitude: Color(hex: "#3A2A16")
        }
    }
}

/// A curated track. Real songs (team-made with ElevenLabs) are dropped into the bundle or CDN;
/// until then `fileName` is nil and the player runs on a silent clock.
struct MusicTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let theme: MusicTheme
    let durationS: Int
    /// Cue moments (e.g. each chorus), authored by the team when the song is made.
    let cueMarkersS: [Int]
    var fileName: String? = nil

    static let catalog: [MusicTrack] = MusicTheme.allCases.flatMap { theme in
        (1...3).map { i in
            let len = 210 + i * 25
            return MusicTrack(id: "\(theme.rawValue)-\(i)", title: "[\(theme.name) track \(i)]", theme: theme,
                              durationS: len, cueMarkersS: stride(from: 38, to: len - 10, by: 42).map { $0 })
        }
    }
    static func byID(_ id: String?) -> MusicTrack? { catalog.first { $0.id == id } }
    static func `default`(for feeling: Feeling) -> MusicTrack {
        let theme: MusicTheme = switch feeling {
        case .gratitude: .gratitude
        case .love: .love
        case .joy, .bliss: .joy
        case .calm: .health
        case .confidence: .business
        }
        return catalog.first { $0.theme == theme }!
    }
    var durationLabel: String { "\(durationS / 60):\(String(format: "%02d", durationS % 60))" }
}

/// Built-in image sets (placeholders until artwork lands).
struct ImageSet: Identifiable, Hashable {
    let id: String
    let name: String
    let feeling: Feeling
    let count: Int
    static let all: [ImageSet] = [
        .init(id: "golden", name: "Golden mornings", feeling: .gratitude, count: 12),
        .init(id: "hearts", name: "Warm hearts", feeling: .love, count: 10),
        .init(id: "sky", name: "Open sky", feeling: .joy, count: 14),
        .init(id: "growth", name: "Green growth", feeling: .confidence, count: 12),
        .init(id: "water", name: "Still water", feeling: .calm, count: 9),
        .init(id: "summit", name: "Summit", feeling: .bliss, count: 11),
    ]
}

struct GuideVideo: Identifiable {
    let id: String
    let title: String
    let meta: String
    let group: String
    static let all: [GuideVideo] = [
        .init(id: "wear", title: "Wearing your ring", meta: "[VIDEO] · 1 min", group: "Getting started"),
        .init(id: "training", title: "How training works", meta: "[VIDEO] · 2 min", group: "Getting started"),
        .init(id: "reminders", title: "Making reminders work for you", meta: "[VIDEO] · 2 min", group: "Getting started"),
        .init(id: "coherence", title: "Coherence breathing, simply", meta: "[VIDEO] · 3 min", group: "Meditation"),
        .init(id: "comfort", title: "Using vibration comfortably", meta: "[VIDEO] · 1 min", group: "Safety & help"),
        .init(id: "connect", title: "Ring not connecting", meta: "Step-by-step fixes", group: "Safety & help"),
    ]
}
