import Foundation
import Observation
import SwiftData
import UIKit
import UserNotifications

/// Calm cue: when you've been still for a while and your ring's readings look tense compared with
/// your normal, the ring plays a slow "slow down" touch and a notification offers a short
/// 4-in / 7-out breath.
///
/// Runs whenever the app gets to run (same wakes as reminder delivery: ring data, app open,
/// notification, background refresh), so on iOS it reacts when new ring data arrives rather
/// than on a fixed timer.
///
/// Rules (all must hold):
/// - you've been **still for 15 minutes**: no workout recording or ended in that time and
///   at most `stepsAllowance` steps — so a walk or a run never counts, and after an activity
///   it waits until you've settled;
/// - a **fresh reading** (last 15 min) is raised: the ring's own stress score, or heart rate
///   above your resting level, or HRV below your usual;
/// - your normal is known (**3+ days** of heart data);
/// - **at most once every 2 hours**, max 4 a day, never in quiet hours or while reminders are paused.
@MainActor
@Observable
final class CalmCueMonitor {
    enum Level: Int, Comparable {
        case none, elevated, high
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
        var label: String { switch self { case .none: "normal"; case .elevated: "raised"; case .high: "high" } }
    }

    struct Baseline {
        var days = 0
        var restingHR: Double?
        var hrvMedian: Double?
        var ready: Bool { days >= CalmCueMonitor.minBaselineDays && restingHR != nil }
    }

    static let stillMinutes: Double = 15
    static let stepsAllowance = 40
    static let readingWindowMinutes: Double = 15
    static let cooldownHours: Double = 2
    static let maxPerDay = 4
    static let minBaselineDays = 3
    static let notificationPrefix = "emotion.calm."

    private let context: ModelContext
    private let services: EmotionServices
    @ObservationIgnored private var lastEvaluation = Date.distantPast
    @ObservationIgnored private var lastLoggedOutcome = ""
    @ObservationIgnored private var baselineCache: (at: Date, value: Baseline)?

    /// Last check in words, for the settings screen.
    private(set) var lastAssessment = "Not checked yet"
    private(set) var log: [String] = UserDefaults.standard.stringArray(forKey: "emotion.calm.log") ?? []

    init(context: ModelContext, services: EmotionServices) {
        self.context = context
        self.services = services
    }

    // MARK: Evaluate

    /// Check now. Cheap; coalesced to once a minute unless `force`.
    func evaluate(trigger: String, force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastEvaluation) > 60 else { return }
        lastEvaluation = now
        recordStepSnapshot()

        let profile = context.emotionProfile()
        guard profile.calmCueEnabled else { lastAssessment = "Calm cue is off"; return }

        let baseline = self.baseline(now: now)
        guard baseline.ready else {
            outcome(trigger, "learning your normal (\(baseline.days) of \(Self.minBaselineDays) days)")
            return
        }
        switch stillness(now: now) {
        case .moving(let why):
            outcome(trigger, "not still · \(why)")
            return
        case .unknown(let why):
            outcome(trigger, "can't tell if still · \(why)")
            return
        case .still:
            break
        }
        let (level, reason) = assess(now: now, baseline: baseline)
        let needed: Level = profile.calmCueSensitivity == "high" ? .high : .elevated
        guard level >= needed else {
            outcome(trigger, "still · readings \(level.label)\(reason.isEmpty ? "" : " (\(reason))")")
            return
        }
        if let why = blocked(now: now, profile: profile) {
            outcome(trigger, "tense (\(reason)) but \(why)")
            return
        }
        fire(reason: reason, level: level, trigger: trigger)
    }

    /// Developer test and "Feel it": play the cue and show the notification, skipping every check.
    func playTest(withNotification: Bool) {
        services.haptics.play(.calmCue)
        if withNotification { postNotification(test: true) }
        append("test · played calm cue\(withNotification ? " + notification" : "")")
    }

    // MARK: Pieces

    private func fire(reason: String, level: Level, trigger: String) {
        let profile = context.emotionProfile()
        profile.lastCalmCueAt = Date()
        var today = UserDefaults.standard.array(forKey: "emotion.calm.sent") as? [Double] ?? []
        today.append(Date().timeIntervalSince1970)
        UserDefaults.standard.set(Array(today.suffix(20)), forKey: "emotion.calm.sent")
        try? context.save()

        let token = BackgroundTime.begin(name: "emotion.calm")
        if services.haptics.isRingConnected {
            services.haptics.play(.calmCue)
            append("\(trigger) · SENT calm cue · \(level.label): \(reason)")
        } else {
            append("\(trigger) · tense (\(reason)) · ring not connected, notification only")
            if !services.haptics.usesSimulator, services.client.hasLastKnownRing { services.client.connectLastKnown() }
            // One retry once the ring is back.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard let self else { return }
                if self.services.haptics.isRingConnected {
                    self.services.haptics.play(.calmCue)
                    self.append("retry · SENT calm cue after reconnecting")
                }
            }
        }
        postNotification(test: false)
        lastAssessment = "Calm cue sent \(Date().formatted(date: .omitted, time: .shortened)) · \(reason)"
        Task {
            try? await Task.sleep(for: .seconds(25))
            BackgroundTime.end(token)
        }
    }

    private func postNotification(test: Bool) {
        let content = UNMutableNotificationContent()
        content.title = test ? "[Test] Feeling tense?" : "Feeling tense?"
        content.body = "Your ring played a slow-down touch. Take a minute: breathe in for 4, out for 7."
        content.userInfo = ["calm": "1"]
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: Self.notificationPrefix + UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func blocked(now: Date, profile: EmotionProfile) -> String? {
        if profile.remindersPaused { return "reminders are paused" }
        if let until = profile.pausedUntil, until > now { return "paused until \(until.formatted(date: .omitted, time: .shortened))" }
        let minute = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let qs = profile.quietStartMinutes, qe = profile.quietEndMinutes
        let quiet = qs > qe ? (minute >= qs || minute < qe) : (minute >= qs && minute < qe)
        if quiet { return "quiet hours" }
        if let last = profile.lastCalmCueAt, now.timeIntervalSince(last) < Self.cooldownHours * 3600 {
            return "last calm cue was \(Int(now.timeIntervalSince(last) / 60)) min ago"
        }
        let sent = (UserDefaults.standard.array(forKey: "emotion.calm.sent") as? [Double] ?? [])
            .filter { Calendar.current.isDateInToday(Date(timeIntervalSince1970: $0)) }
        if sent.count >= Self.maxPerDay { return "already \(Self.maxPerDay) today" }
        return nil
    }

    enum Stillness { case still, moving(String), unknown(String) }

    /// Still = no workout in the window and at most a few steps across at least 15 minutes.
    func stillness(now: Date) -> Stillness {
        let since = now.addingTimeInterval(-Self.stillMinutes * 60)
        let sessions = (try? context.fetch(FetchDescriptor<ActivitySession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))) ?? []
        for s in sessions.prefix(5) {
            if s.endedAt == nil, s.statusRaw == ActivitySessionStatus.recording.rawValue || s.statusRaw == ActivitySessionStatus.paused.rawValue {
                return .moving("workout in progress")
            }
            if let end = s.endedAt, end > since { return .moving("workout ended \(Int(now.timeIntervalSince(end) / 60)) min ago") }
        }
        // Step snapshots: one at least 15 min old and one fresh.
        let snaps = stepSnapshots()
        guard let fresh = snaps.last, now.timeIntervalSince(fresh.at) < 10 * 60 else {
            return .unknown("no fresh step count from the ring")
        }
        guard let old = snaps.last(where: { $0.at <= since && now.timeIntervalSince($0.at) < 90 * 60 }) else {
            return .unknown("step history covers less than \(Int(Self.stillMinutes)) min")
        }
        let delta = Calendar.current.isDate(old.at, inSameDayAs: fresh.at) ? fresh.steps - old.steps : fresh.steps
        if delta > Self.stepsAllowance { return .moving("\(delta) steps since \(old.at.formatted(date: .omitted, time: .shortened))") }
        return .still
    }

    /// Compare fresh readings with the personal baseline.
    func assess(now: Date, baseline: Baseline) -> (Level, String) {
        let since = now.addingTimeInterval(-Self.readingWindowMinutes * 60)
        var level = Level.none
        var reasons: [String] = []

        let stress = readings(.stress, since: since)
        if let s = stress.first?.value {
            // Ring stress score 0–100 (Colmi app bands: 60–79 medium, 80+ high).
            let l: Level = s >= 80 ? .high : s >= 60 ? .elevated : .none
            if l > .none { reasons.append("stress \(Int(s))") }
            level = max(level, l)
        }
        let hr = readings(.heartRate, since: since).map(\.value).filter { $0 >= 35 && $0 <= 200 }
        if hr.count >= 2, let rest = baseline.restingHR, let low = hr.min() {
            let over = low - rest
            let l: Level = over >= 25 ? .high : over >= 15 ? .elevated : .none
            if l > .none { reasons.append("heart \(Int(low))+ bpm vs \(Int(rest)) resting") }
            level = max(level, l)
        }
        if let v = readings(.hrv, since: now.addingTimeInterval(-30 * 60)).first?.value, let median = baseline.hrvMedian, median > 0 {
            let ratio = v / median
            let l: Level = ratio <= 0.6 ? .high : ratio <= 0.75 ? .elevated : .none
            if l > .none { reasons.append("HRV \(Int(v)) vs usual \(Int(median)) ms") }
            level = max(level, l)
        }
        if stress.isEmpty && hr.count < 2 && reasons.isEmpty { reasons.append("no fresh readings") }
        return (level, reasons.joined(separator: ", "))
    }

    /// Resting heart rate (20th percentile) and usual HRV (median) over the last 7 days.
    func baseline(now: Date = Date()) -> Baseline {
        if let c = baselineCache, now.timeIntervalSince(c.at) < 3600 { return c.value }
        let since = now.addingTimeInterval(-7 * 86_400)
        var b = Baseline()
        let hr = readings(.heartRate, since: since).filter { $0.value >= 35 && $0.value <= 200 }
        b.days = Set(hr.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        if hr.count >= 40 {
            let sorted = hr.map(\.value).sorted()
            b.restingHR = sorted[Int(Double(sorted.count) * 0.2)]
        }
        let hrv = readings(.hrv, since: since).map(\.value).filter { $0 > 0 }.sorted()
        if hrv.count >= 10 { b.hrvMedian = hrv[hrv.count / 2] }
        baselineCache = (now, b)
        return b
    }

    private func readings(_ kind: MeasurementKind, since: Date) -> [Measurement] {
        let raw = kind.rawValue
        let excluded = [MeasurementSource.mock.rawValue, MeasurementSource.workout.rawValue]
        let d = FetchDescriptor<Measurement>(
            predicate: #Predicate { $0.kindRaw == raw && $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return ((try? context.fetch(d)) ?? []).filter { !excluded.contains($0.sourceRaw) && $0.activitySessionId == nil }
    }

    // MARK: Step snapshots (today's total as the ring reports it, with when it changed)

    private struct StepSnap: Codable { let at: Date; let steps: Int }
    private static let snapsKey = "emotion.calm.stepSnaps"

    private func stepSnapshots() -> [StepSnap] {
        guard let data = UserDefaults.standard.data(forKey: Self.snapsKey),
              let list = try? JSONDecoder().decode([StepSnap].self, from: data) else { return [] }
        return list
    }

    private func recordStepSnapshot() {
        let today = Calendar.current.startOfDay(for: Date())
        let d = FetchDescriptor<ActivityDaily>(predicate: #Predicate { $0.date == today })
        guard let row = (try? context.fetch(d))?.first else { return }
        var list = stepSnapshots()
        // Each sync stamps updatedAt; a sync with no new steps still proves the count is current.
        let at = max(row.updatedAt, row.syncedAt ?? .distantPast)
        if let last = list.last, last.at >= at { return }
        list.append(StepSnap(at: at, steps: row.steps))
        list = list.filter { Date().timeIntervalSince($0.at) < 3 * 3600 }
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: Self.snapsKey) }
    }

    // MARK: Log

    private func outcome(_ trigger: String, _ text: String) {
        lastAssessment = "\(Date().formatted(date: .omitted, time: .shortened)) · \(text)"
        // Log changes only, so the list shows decisions rather than every wake.
        if text != lastLoggedOutcome {
            lastLoggedOutcome = text
            append("\(trigger) · \(text)")
        }
    }

    private func append(_ line: String) {
        log.insert("\(Date().formatted(date: .omitted, time: .standard)) · \(line)", at: 0)
        if log.count > 40 { log.removeLast(log.count - 40) }
        UserDefaults.standard.set(log, forKey: "emotion.calm.log")
    }

    func clearLog() {
        log = []
        UserDefaults.standard.removeObject(forKey: "emotion.calm.log")
    }
}

extension TouchPattern {
    /// Calm cue: three soft hums with lengthening gaps, like a breath slowing down.
    static let calmCue = TouchPattern(id: "calm.cue", name: "Slow down", durationsMs: [800, 1200, 800, 1800, 800])
}
