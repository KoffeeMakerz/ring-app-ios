import Foundation
import SwiftData

/// One per install: onboarding progress and personal settings for the emotion app.
@Model
final class EmotionProfile {
    var onboardingCompleted: Bool = false
    var firstFeelingRaw: String = Feeling.gratitude.rawValue
    var activeFeelingRaw: String = Feeling.gratitude.rawValue
    var consentReminders: Bool = true
    var consentHeartData: Bool = false
    var consentPhotos: Bool = false
    /// Shortest gap between two buzzes the user could feel, from the vibration test (ms).
    var minFeltGapMs: Int = 600
    var buzzComfort: String = "right"           // strong / right / weak
    var remindersPaused: Bool = false
    var pausedUntil: Date? = nil
    var dailyCap: Int = 6
    var quietStartMinutes: Int = 21 * 60
    var quietEndMinutes: Int = 8 * 60
    var ringGuidesBreath: Bool = true
    var liveHeartFeedback: Bool = true
    var breathInSeconds: Double = 5
    var breathOutSeconds: Double = 5
    var calmCueEnabled: Bool = false
    var statsHeart: Bool = true
    var statsSleep: Bool = false
    var statsActivity: Bool = false
    var createdAt: Date = Date()

    init() {}

    var firstFeeling: Feeling { Feeling(rawValue: firstFeelingRaw) ?? .gratitude }
    var activeFeeling: Feeling {
        get { Feeling(rawValue: activeFeelingRaw) ?? .gratitude }
        set { activeFeelingRaw = newValue.rawValue }
    }
}

/// An experience = a vision (title + point-form text) felt through an ordered arc of 1–3 feelings
/// (e.g. joy, then gratitude), with music and optional images.
@Model
final class Experience {
    var id: UUID = UUID()
    var title: String = ""
    var visionPoints: [String] = []
    /// The first feeling of the arc (kept for older data and single-feeling lookups).
    var feelingRaw: String = Feeling.gratitude.rawValue
    /// The full ordered arc. Empty on experiences made before v2: then the arc is just `feelingRaw`.
    var feelingsRaw: [String] = []
    var trackID: String = ""
    /// "app:<setID>" for a built-in set, or "photo:<PHAsset localIdentifier>" for device photos (never uploaded).
    var imageRefs: [String] = []
    var cueAuto: Bool = true
    /// Custom touch override (JSON of TouchPattern); nil = the feeling's own touch.
    var customTouchData: Data? = nil
    var createdAt: Date = Date()
    var lastPlayedAt: Date? = nil

    init(title: String = "", points: [String] = [], feelings: [Feeling] = [.gratitude], trackID: String? = nil) {
        let arc = feelings.isEmpty ? [Feeling.gratitude] : feelings
        self.title = title
        self.visionPoints = points
        self.feelingRaw = arc[0].rawValue
        self.feelingsRaw = arc.map(\.rawValue)
        self.trackID = trackID ?? MusicTrack.default(for: arc[0]).id
    }

    /// The first feeling of the arc.
    var feeling: Feeling {
        get { Feeling(rawValue: feelingRaw) ?? .gratitude }
        set { feelings = [newValue] }
    }
    /// The ordered arc of 1–3 feelings.
    var feelings: [Feeling] {
        get {
            let arc = feelingsRaw.compactMap(Feeling.init(rawValue:))
            return arc.isEmpty ? [feeling] : arc
        }
        set {
            let arc = Array((newValue.isEmpty ? [Feeling.gratitude] : newValue).prefix(Feeling.maxPerExperience))
            feelingsRaw = arc.map(\.rawValue)
            feelingRaw = arc[0].rawValue
        }
    }
    /// Each feeling's own touch, in order, at least 4 s apart: what reminders for this vision play.
    var touchSequence: TouchPattern { Feeling.sequence(feelings) }
    var arcLabel: String { feelings.map(\.name).joined(separator: " → ") }
    var track: MusicTrack { MusicTrack.byID(trackID) ?? MusicTrack.default(for: feeling) }
    var touch: TouchPattern {
        get {
            if let data = customTouchData, let p = try? JSONDecoder().decode(TouchPattern.self, from: data) { return p }
            return feeling.touch
        }
        set { customTouchData = newValue.id.hasPrefix("feeling.") ? nil : try? JSONEncoder().encode(newValue) }
    }
    var photoIdentifiers: [String] { imageRefs.compactMap { $0.hasPrefix("photo:") ? String($0.dropFirst(6)) : nil } }
    var imageSetID: String? { imageRefs.first { $0.hasPrefix("app:") }.map { String($0.dropFirst(4)) } }
    var imagesLabel: String {
        if !photoIdentifiers.isEmpty { return "\(photoIdentifiers.count) of your photos" }
        if let set = ImageSet.all.first(where: { $0.id == imageSetID }) { return set.name }
        return "No images"
    }
}

/// A user-made touch from the optional composer.
@Model
final class CustomTouch {
    var id: UUID = UUID()
    var name: String = "My touch"
    var blocksRaw: [String] = []
    var createdAt: Date = Date()
    init(name: String, blocks: [TouchBlock]) {
        self.name = name
        self.blocksRaw = blocks.map(\.rawValue)
    }
    var blocks: [TouchBlock] { blocksRaw.compactMap(TouchBlock.init(rawValue:)) }
    var pattern: TouchPattern { TouchBlock.compose(blocks, id: "custom.\(id.uuidString)", name: name) }
}

@Model
final class TrainingRecord {
    var id: UUID = UUID()
    var feelingRaw: String = Feeling.gratitude.rawValue
    var experienceID: UUID? = nil
    var recallRating: Int = 0       // 1–5
    var comfort: String = "right"
    var completedAt: Date = Date()
    init(feeling: Feeling, experienceID: UUID?, rating: Int, comfort: String) {
        self.feelingRaw = feeling.rawValue
        self.experienceID = experienceID
        self.recallRating = rating
        self.comfort = comfort
    }
    var feeling: Feeling { Feeling(rawValue: feelingRaw) ?? .gratitude }
}

@Model
final class ReminderRule {
    var id: UUID = UUID()
    var feelingRaw: String = Feeling.gratitude.rawValue
    var perDay: Int = 3
    var windowStartMinutes: Int = 9 * 60
    var windowEndMinutes: Int = 20 * 60
    var randomTimes: Bool = true
    var fixedMinutes: [Int] = []
    var weekdaysOnly: Bool = false
    /// Days for set times, Monday-first (7 flags). Empty = every day.
    var fixedDays: [Bool] = []
    /// When set, cues for this rule recall this experience and play its touch sequence.
    var experienceID: UUID? = nil
    var checkInAfter: Bool = true
    var enabled: Bool = true
    var createdAt: Date = Date()
    init(feeling: Feeling, perDay: Int = 3) {
        self.feelingRaw = feeling.rawValue
        self.perDay = perDay
    }
    var feeling: Feeling { Feeling(rawValue: feelingRaw) ?? .gratitude }
}

@Model
final class ReminderEvent {
    var id: UUID = UUID()
    var ruleID: UUID? = nil
    var feelingRaw: String = Feeling.gratitude.rawValue
    var scheduledAt: Date = Date()
    var deliveredAt: Date? = nil
    var status: String = "scheduled"   // scheduled / delivered / missed / snoozed
    var feltRating: Int? = nil          // 0 no · 1 a little · 2 yes
    var note: String? = nil
    var experienceID: UUID? = nil
    init(ruleID: UUID?, feeling: Feeling, at date: Date, experienceID: UUID? = nil) {
        self.ruleID = ruleID
        self.feelingRaw = feeling.rawValue
        self.scheduledAt = date
        self.experienceID = experienceID
    }
    var feeling: Feeling { Feeling(rawValue: feelingRaw) ?? .gratitude }
}

@Model
final class MeditationRecord {
    var id: UUID = UUID()
    var kind: String = "journey"   // journey / relax / coherence
    var durationS: Int = 0
    var lowS: Int = 0
    var mediumS: Int = 0
    var highS: Int = 0
    var hrStart: Int? = nil
    var hrEnd: Int? = nil
    var feelAfter: String? = nil
    var completedAt: Date = Date()
    init(kind: String) { self.kind = kind }
}

enum EmotionSchema {
    static let models: [any PersistentModel.Type] = [
        EmotionProfile.self, Experience.self, CustomTouch.self, TrainingRecord.self,
        ReminderRule.self, ReminderEvent.self, MeditationRecord.self,
    ]
}

extension ModelContext {
    /// The single profile row, created on first use.
    func emotionProfile() -> EmotionProfile {
        if let existing = try? fetch(FetchDescriptor<EmotionProfile>()).first { return existing }
        let profile = EmotionProfile()
        insert(profile)
        try? save()
        return profile
    }
}
