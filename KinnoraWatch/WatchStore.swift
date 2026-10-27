import Foundation
import UserNotifications
import WatchKit

/// What the iPhone last synced (experiences and the reminder plan), kept on the watch so the app
/// works with the phone out of reach. The watch delivers the reminders itself as notifications.
final class WatchStore: ObservableObject {
    static let shared = WatchStore()

    @Published private(set) var experiences: [WatchExperience] = []
    @Published private(set) var reminders: [WatchReminder] = []
    @Published private(set) var syncedAt: Date?
    /// Set when a reminder notification is opened: the screen to show.
    @Published var pending: Pending?

    enum Pending: Hashable {
        case experience(String)
        case feeling(String)
    }

    static let notificationCategory = "kinnora.cue"
    static let startAction = "kinnora.start"
    private let key = "kinnora.sync"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            experiences = saved.experiences
            reminders = saved.reminders
            syncedAt = saved.syncedAt
        }
    }

    var upcoming: [WatchReminder] { reminders.filter { $0.date > Date() }.sorted { $0.at < $1.at } }
    func experience(_ id: String?) -> WatchExperience? { experiences.first { $0.id == id } }

    private struct Saved: Codable {
        let experiences: [WatchExperience]
        let reminders: [WatchReminder]
        let syncedAt: Date
    }

    /// The iPhone's sync payload: `["type": "sync", "experiences": [...], "reminders": [...]]`.
    func apply(_ payload: [String: Any]) {
        let decoder = JSONDecoder()
        func decode<T: Decodable>(_ key: String, as: T.Type) -> T? {
            guard let raw = payload[key], JSONSerialization.isValidJSONObject(raw),
                  let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }
        let exps = decode("experiences", as: [WatchExperience].self) ?? []
        let rems = decode("reminders", as: [WatchReminder].self) ?? []
        let now = Date()
        if let data = try? JSONEncoder().encode(Saved(experiences: exps, reminders: rems, syncedAt: now)) {
            UserDefaults.standard.set(data, forKey: key)
        }
        DispatchQueue.main.async {
            self.experiences = exps
            self.reminders = rems
            self.syncedAt = now
        }
        schedule(rems)
    }

    /// Replaces Kinnora's watch notifications with the plan (the 60 soonest).
    private func schedule(_ reminders: [WatchReminder]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("kinnora.cue.") })
            let now = Date()
            for reminder in reminders.filter({ $0.date > now }).sorted(by: { $0.at < $1.at }).prefix(60) {
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.body
                content.sound = .default
                content.categoryIdentifier = Self.notificationCategory
                var info: [String: Any] = ["feeling": reminder.feeling, "durations_ms": reminder.durations]
                if let exp = reminder.experienceID { info["experience"] = exp }
                content.userInfo = info
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.date)
                center.add(UNNotificationRequest(identifier: "kinnora.cue.\(reminder.id)", content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }
    }

    /// Registers the reminder notification's "Start" button.
    static func registerCategory() {
        let start = UNNotificationAction(identifier: startAction, title: "Start", options: [.foreground])
        let category = UNNotificationCategory(identifier: notificationCategory, actions: [start], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// A reminder notification was opened or started: play its touch and open the right screen.
    func open(reminderInfo info: [AnyHashable: Any]) {
        let durations = (info["durations_ms"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
        let feeling = WatchFeeling.named(info["feeling"] as? String)
        HapticPlayer.play(Pattern(name: feeling.name, durationsMs: durations.isEmpty ? feeling.durationsMs : durations))
        DispatchQueue.main.async {
            if let exp = info["experience"] as? String, self.experience(exp) != nil {
                self.pending = .experience(exp)
            } else {
                self.pending = .feeling(feeling.id)
            }
        }
    }
}
