import Foundation
import SwiftData
import UserNotifications

/// Plans reminder times and delivers them.
///
/// Delivery: at each time the **app sends the touch to the ring** (the experience's whole sequence,
/// each feeling's touch ≥4 s apart). On iPhone the app can only do that when iOS lets it run
/// (foreground, or woken by Bluetooth activity from the ring), so a cue can land a few minutes off.
/// A **phone notification** with the cue prompt is always scheduled as well, so a reminder is never lost.
@MainActor
final class ReminderScheduler {
    static let notificationCategory = "emotion.cue"

    /// Random (or fixed) times for one rule on one day, respecting window and quiet hours.
    static func plannedTimes(for rule: ReminderRule, on day: Date, profile: EmotionProfile, calendar: Calendar = .current) -> [Date] {
        let startOfDay = calendar.startOfDay(for: day)
        if rule.weekdaysOnly, calendar.isDateInWeekend(day) { return [] }
        if !rule.randomTimes, rule.fixedDays.count == 7 {
            let mondayFirst = (calendar.component(.weekday, from: day) + 5) % 7
            if !rule.fixedDays[mondayFirst] { return [] }
        }
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
        // Set times are exactly what the person chose; quiet hours only shape spread reminders.
        return minutes.filter { !rule.randomTimes || allowed($0) }.sorted().compactMap {
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
        for (rule, date) in planned {
            context.insert(ReminderEvent(ruleID: rule.id, feeling: rule.feeling, at: date, experienceID: rule.experienceID))
        }
        try? context.save()

        let experiences = (try? context.fetch(FetchDescriptor<Experience>())) ?? []
        scheduleNotifications(planned.map { rule, date in
            CueItem(feeling: rule.feeling, date: date, experience: experiences.first { $0.id == rule.experienceID })
        })
    }

    struct CueItem {
        let feeling: Feeling
        let date: Date
        let experience: Experience?
    }

    private static func scheduleNotifications(_ items: [CueItem]) {
        let payload: [(title: String, body: String, info: [String: String], date: Date)] = items.prefix(60).map { item -> (title: String, body: String, info: [String: String], date: Date) in
            if let exp = item.experience {
                let arc = exp.feelings.map { $0.name.lowercased() }.joined(separator: ", then ")
                let picture = exp.visionPoints.first.map { "Picture it: \($0). " } ?? ""
                return (exp.title, "\(picture)Feel \(arc).", ["feeling": item.feeling.rawValue, "experience": exp.id.uuidString], item.date)
            }
            return ("\(item.feeling.name) cue", item.feeling.cuePrompt, ["feeling": item.feeling.rawValue], item.date)
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.filter { $0.identifier.hasPrefix("emotion.cue.") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ours)
            for (title, body, info, date) in payload {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.categoryIdentifier = notificationCategory
                content.userInfo = info
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

