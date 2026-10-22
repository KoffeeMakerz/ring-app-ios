import BackgroundTasks
import Foundation
import Observation
import SwiftData
import UIKit

/// Sends due reminder cues to the ring. The phone sends every vibration command; nothing is
/// scheduled on the ring.
///
/// iOS gives no guaranteed timed background execution, so delivery is opportunistic: the
/// dispatcher checks for due cues whenever the app gets to run —
/// - **ring data**: Bluetooth activity from the connected ring wakes the app (bluetooth-central
///   background mode; iOS relaunches the app for ring events via state restoration),
/// - **foreground**: the app is opened or is on screen (30 s timer),
/// - **notification**: the cue notification arrives while the app is in the foreground,
/// - **background refresh**: an opportunistic `BGAppRefreshTask`.
///
/// Rules: each cue plays at most once (marked delivered before playing); cues more than
/// `graceSeconds` late are skipped as missed; if several are due at once only the newest plays;
/// if the ring is disconnected the dispatcher reconnects and retries up to `maxAttempts` times.
@MainActor
@Observable
final class CueDispatcher {
    enum Trigger: String {
        case ringData = "ring data"
        case foreground = "app open"
        case notification = "notification"
        case backgroundRefresh = "background refresh"
        case retry = "retry"
        case manual = "manual check"
    }

    static let graceSeconds: TimeInterval = 15 * 60
    static let maxAttempts = 3
    static let retryDelaySeconds: UInt64 = 20

    private let context: ModelContext
    private let services: EmotionServices
    private var busTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var lastRingDataCheck = Date.distantPast
    private var checking = false
    private(set) var lastCheckAt: Date?
    private(set) var lastTrigger: Trigger?

    init(context: ModelContext, services: EmotionServices) {
        self.context = context
        self.services = services
    }

    func start() {
        guard busTask == nil else { return }
        busTask = Task { [weak self] in
            let stream = await PulseEventBus.shared.stream()
            for await _ in stream {
                guard let self else { return }
                // Any ring traffic means we're running; coalesce bursts.
                if Date().timeIntervalSince(self.lastRingDataCheck) > 20 {
                    self.lastRingDataCheck = Date()
                    self.check(.ringData)
                }
            }
        }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                if UIApplication.shared.applicationState == .active { self.check(.foreground) }
            }
        }
    }

    /// Recent wakes and what happened, newest first (kept across launches for the developer test).
    static let wakeLogKey = "emotion.cue.wakeLog"
    private(set) var wakeLog: [String] = UserDefaults.standard.stringArray(forKey: CueDispatcher.wakeLogKey) ?? []

    private func logWake(_ trigger: Trigger, _ outcome: String) {
        let state: String
        switch UIApplication.shared.applicationState {
        case .active: state = "open"
        case .inactive: state = "inactive"
        case .background: state = "background/locked"
        @unknown default: state = "?"
        }
        let line = "\(Date().formatted(date: .omitted, time: .standard)) · \(trigger.rawValue) · app \(state) · \(outcome)"
        wakeLog.insert(line, at: 0)
        if wakeLog.count > 60 { wakeLog.removeLast(wakeLog.count - 60) }
        UserDefaults.standard.set(wakeLog, forKey: Self.wakeLogKey)
    }

    func clearWakeLog() {
        wakeLog = []
        UserDefaults.standard.removeObject(forKey: Self.wakeLogKey)
    }

    /// Deliver whatever is due now. Safe to call often.
    func check(_ trigger: Trigger) {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        // Same wakes drive the calm cue check (it coalesces to once a minute).
        services.calm?.evaluate(trigger: trigger.rawValue)
        lastCheckAt = Date()
        lastTrigger = trigger
        // Ring-data wakes are frequent while open; only log them when the app isn't on screen.
        let quiet = trigger == .ringData && UIApplication.shared.applicationState == .active

        let now = Date()
        let scheduled = "scheduled"
        let due = ((try? context.fetch(FetchDescriptor<ReminderEvent>(
            predicate: #Predicate { $0.status == scheduled && $0.scheduledAt <= now },
            sortBy: [SortDescriptor(\.scheduledAt)]))) ?? [])
        guard !due.isEmpty else {
            if !quiet { logWake(trigger, "nothing due") }
            return
        }

        var live: [ReminderEvent] = []
        for event in due {
            let late = now.timeIntervalSince(event.scheduledAt)
            if late > Self.graceSeconds {
                event.status = "missed"
                event.deliveredVia = "skipped · \(Int(late / 60)) min late, app wasn't woken in time"
            } else {
                live.append(event)
            }
        }
        guard let latest = live.last else {
            logWake(trigger, "skipped \(due.count) late cue(s)")
            try? context.save(); return
        }
        for older in live.dropLast() {
            older.status = "missed"
            older.deliveredVia = "merged with the \(hm(minutesOfDay(latest.scheduledAt))) cue"
        }

        guard services.haptics.isRingConnected else {
            latest.attempts += 1
            logWake(trigger, "cue due but ring not connected (try \(latest.attempts))")
            if latest.attempts >= Self.maxAttempts {
                latest.status = "missed"
                latest.deliveredVia = "ring not connected after \(Self.maxAttempts) tries"
            } else {
                if !services.haptics.usesSimulator, services.client.hasLastKnownRing { services.client.connectLastKnown() }
                scheduleRetry()
            }
            try? context.save()
            return
        }
        deliver(latest, via: trigger, now: now)
    }

    private func deliver(_ event: ReminderEvent, via trigger: Trigger, now: Date) {
        let pattern: TouchPattern
        if let id = event.experienceID,
           let exp = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first {
            pattern = exp.touchSequence
        } else {
            pattern = event.feeling.touch
        }
        // Mark first so a second wake can never play the same cue twice.
        event.status = "delivered"
        event.deliveredAt = now
        event.delaySeconds = max(0, Int(now.timeIntervalSince(event.scheduledAt)))
        event.deliveredVia = trigger.rawValue
        try? context.save()
        logWake(trigger, "SENT to ring · \(event.delaySeconds! / 60) min late")

        // Ask iOS for enough background time to send the whole sequence.
        let token = BackgroundTime.begin(name: "emotion.cue")
        services.haptics.play(pattern)
        Task {
            try? await Task.sleep(for: .milliseconds(pattern.totalMs + 1_500))
            BackgroundTime.end(token)
        }
    }

    private func scheduleRetry() {
        retryTask?.cancel()
        let token = BackgroundTime.begin(name: "emotion.cue.retry")
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.retryDelaySeconds * 1_000_000_000)
            if !Task.isCancelled { self?.check(.retry) }
            BackgroundTime.end(token)
        }
    }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

/// Wraps `beginBackgroundTask` so the expiration handler can end the task it belongs to.
@MainActor
final class BackgroundTime {
    private var id: UIBackgroundTaskIdentifier = .invalid

    static func begin(name: String) -> BackgroundTime {
        let token = BackgroundTime()
        token.id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak token] in
            Task { @MainActor in token.map(BackgroundTime.end) }
        }
        return token
    }

    static func end(_ token: BackgroundTime) {
        guard token.id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(token.id)
        token.id = .invalid
    }
}

/// Opportunistic background refresh: keeps the next days of reminders planned and delivers any
/// cue that's due. iOS decides when (and whether) it runs.
enum ReminderBackgroundRefresh {
    static let identifier = "emotion.reminders.refresh"

    /// Must be called before the app finishes launching.
    static func register(handler: @escaping @MainActor () -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            task.expirationHandler = { task.setTaskCompleted(success: false) }
            Task { @MainActor in
                handler()
                schedule()
                task.setTaskCompleted(success: true)
            }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
