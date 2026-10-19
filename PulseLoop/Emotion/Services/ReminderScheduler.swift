import Foundation
import SwiftData
import UserNotifications

/// Plans reminder times and delivers them.
///
/// Delivery paths (see the implementation plan):
/// 1. **Ring-stored alarms** (main path, phone can be locked): write the day's times into the ring's
///    alarm slots when connected. `RingAlarmWriter` is the hook; per-family encoders are Phase 0/4 work.
/// 2. **Phone notification** with the cue prompt — always scheduled, so a reminder is never lost.
/// 3. **Full feeling touch** played by the app when it is awake at the cue time.
@MainActor
final class ReminderScheduler {
    static let notificationCategory = "emotion.cue"

    /// Random (or fixed) times for one rule on one day, respecting window and quiet hours.
    static func plannedTimes(for rule: ReminderRule, on day: Date, profile: EmotionProfile, calendar: Calendar = .current) -> [Date] {
        let startOfDay = calendar.startOfDay(for: day)
        if rule.weekdaysOnly, calendar.isDateInWeekend(day) { return [] }
        func allowed(_ minute: Int) -> Bool {
            let qs = profile.quietStartMinutes, qe = profile.quietEndMinutes
            let inQuiet = qs > qe ? (minute >= qs || minute < qe) : (minute >= qs && minute < qe)
            return !inQuiet
        }
        var minutes: [Int]
        if rule.randomTimes {
            let span = max(1, rule.windowEndMinutes - rule.windowStartMinutes)
            let slot = span / max(1, rule.perDay)
            // Deterministic per rule + day, so re-planning the same day gives the same times.
            var seed = UInt64(abs(rule.id.hashValue)) &+ UInt64(startOfDay.timeIntervalSince1970)
            minutes = (0..<rule.perDay).map { i in
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let jitter = Int(seed >> 33) % max(1, slot - 10)
                return rule.windowStartMinutes + i * slot + 5 + jitter
            }
        } else {
            minutes = rule.fixedMinutes
        }
        return minutes.filter(allowed).sorted().compactMap {
            calendar.date(byAdding: .minute, value: $0, to: startOfDay)
        }
    }

    /// Rebuild the next 3 days of reminders: events + phone notifications (+ ring alarms when supported).
    static func rebuild(context: ModelContext) {
        let profile = context.emotionProfile()
        let rules = (try? context.fetch(FetchDescriptor<ReminderRule>())) ?? []
        let now = Date()
        // Drop future scheduled events; keep history.
        let future = (try? context.fetch(FetchDescriptor<ReminderEvent>(predicate: #Predicate { $0.status == "scheduled" }))) ?? []
        for event in future where event.scheduledAt > now { context.delete(event) }

        var planned: [(ReminderRule, Date)] = []
        for offset in 0..<3 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now) else { continue }
            var dayTimes: [(ReminderRule, Date)] = []
            for rule in rules where rule.enabled {
                dayTimes += plannedTimes(for: rule, on: day, profile: profile).map { (rule, $0) }
            }
            dayTimes = dayTimes.filter { $0.1 > now }.sorted { $0.1 < $1.1 }
            planned += dayTimes.prefix(profile.dailyCap)
        }
        if profile.remindersPaused, let until = profile.pausedUntil {
            planned = planned.filter { $0.1 > until }
        }
        for (rule, date) in planned { context.insert(ReminderEvent(ruleID: rule.id, feeling: rule.feeling, at: date)) }
        try? context.save()

        scheduleNotifications(planned.map { ($0.0.feeling, $0.1) })
        RingAlarmWriter.shared.write(planned.map { ($0.0.feeling, $0.1) })
    }

    private static func scheduleNotifications(_ items: [(Feeling, Date)]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.filter { $0.identifier.hasPrefix("emotion.cue.") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for (feeling, date) in items.prefix(60) {
                let content = UNMutableNotificationContent()
                content.title = "\(feeling.name) cue"
                content.body = feeling.cuePrompt
                content.categoryIdentifier = notificationCategory
                content.userInfo = ["feeling": feeling.rawValue]
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "emotion.cue.\(Int(date.timeIntervalSince1970))", content: content, trigger: trigger))
            }
        }
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

/// Writes upcoming reminders into the ring's own alarm slots so they fire with the phone locked.
/// Per-family encoders (Colmi `0x23`, RWfit key `0x02/0x10`) land in Phase 0/4; until then this
/// records the intent so the UI can show the delivery path.
@MainActor
final class RingAlarmWriter {
    static let shared = RingAlarmWriter()
    private(set) var lastWritten: [(Feeling, Date)] = []
    func write(_ items: [(Feeling, Date)]) { lastWritten = items }
}
