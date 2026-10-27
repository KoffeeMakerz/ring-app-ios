import Foundation
import Observation
import SwiftData
import WatchConnectivity

/// How touches are routed when more than one device is in use. The ring comes first.
enum TouchTarget: String, CaseIterable, Identifiable {
    /// The ring when it's connected; the watch only when no ring is connected.
    case ringFirst
    /// The ring and the watch together.
    case both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ringFirst: "Ring first"
        case .both: "Both"
        }
    }
    var detail: String {
        switch self {
        case .ringFirst: "Touches go to your ring. Your watch takes over when the ring isn't connected."
        case .both: "Every touch plays on your ring and your watch together."
        }
    }
    /// Older builds stored "ring", "watch" or "both".
    init(stored: String?) { self = stored == "both" ? .both : .ringFirst }
}

/// The link to the Kinnora app on a paired Apple Watch (WatchConnectivity).
///
/// Every touch the app plays (practice, experiences, reminders, the calm cue, tests) is also sent
/// to the watch, which plays it on its Taptic Engine. watchOS only accepts live messages while
/// the Kinnora watch app is running, so touches reach the watch while that app is open (it keeps
/// itself awake during a session). Reminders still reach the wrist either way: the iPhone's cue
/// notification is shown on the watch.
///
/// Message format (same as `watch/KinnoraWatch/WatchSession.swift`):
/// `["type": "play", "pattern": ["id", "name", "durations_ms": [on, off, on, …]]]`, starting with on.
@MainActor
@Observable
final class WatchLink: NSObject {
    static let targetKey = "emotion.touchTarget"

    private(set) var isPaired = false
    private(set) var isAppInstalled = false
    private(set) var isReachable = false
    private(set) var lastSentAt: Date?
    private(set) var lastError: String?

    var target: TouchTarget = TouchTarget(stored: UserDefaults.standard.string(forKey: WatchLink.targetKey)) {
        didSet { UserDefaults.standard.set(target.rawValue, forKey: Self.targetKey) }
    }

    static let useWatchKey = "emotion.useWatch"
    /// Kinnora's "Use a watch" switch (Devices tab). Off = nothing is sent to the watch.
    var useWatch: Bool = UserDefaults.standard.object(forKey: WatchLink.useWatchKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(useWatch, forKey: Self.useWatchKey)
            rebuildReminders()
        }
    }

    static let remindersKey = "emotion.watchReminders"
    /// "Reminders on the watch": with the watch app installed, the watch delivers the reminder plan
    /// itself and the iPhone shows no cue notifications of its own.
    var remindersOnWatch: Bool = UserDefaults.standard.object(forKey: WatchLink.remindersKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(remindersOnWatch, forKey: Self.remindersKey)
            rebuildReminders()
        }
    }
    var takesOverReminders: Bool { useWatch && remindersOnWatch && isPaired && isAppInstalled }

    /// The watch asked to play an experience on the iPhone (set by the root view).
    var onStartExperience: ((UUID) -> Void)?
    private(set) var lastSyncAt: Date?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var planObserver: NSObjectProtocol?
    @ObservationIgnored private var saveObserver: NSObjectProtocol?
    @ObservationIgnored private var pendingSync: Task<Void, Never>?

    /// Gives the link the app's data, so it can send experiences and the reminder plan to the watch.
    func attach(_ context: ModelContext) {
        self.context = context
        planObserver = NotificationCenter.default.addObserver(forName: ReminderScheduler.planChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        // Any saved change (a new, edited or deleted experience) goes to the watch too.
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleSync() }
        }
        sync()
    }

    /// Coalesces bursts of saves (the builder saves several times) into one sync.
    private func scheduleSync() {
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.sync()
        }
    }

    private func rebuildReminders() {
        guard let context else { return }
        ReminderScheduler.rebuild(context: context) // posts planChanged → sync
    }

    /// Sends the experiences and the reminder plan as application context: the watch gets the latest
    /// copy even if its app isn't running, and keeps it for when the phone is out of reach.
    func sync() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, isPaired, isAppInstalled,
              useWatch, let context else { return }
        let experiences = (try? context.fetch(FetchDescriptor<Experience>())) ?? []
        let scheduled = "scheduled"
        let now = Date()
        let events = ((try? context.fetch(FetchDescriptor<ReminderEvent>(
            predicate: #Predicate { $0.status == scheduled && $0.scheduledAt > now },
            sortBy: [SortDescriptor(\.scheduledAt)]))) ?? []).filter { !$0.isTest }.prefix(60)

        func onFirst(_ p: TouchPattern) -> [Int] { p.startsWithVibration ? p.durationsMs : [0] + p.durationsMs }

        let exps: [[String: Any]] = experiences.prefix(40).map { exp in
            let track = exp.track
            let duration = max(1, track.durationS)
            let n = max(1, exp.feelings.count)
            let custom = exp.customTouchData == nil ? nil : exp.touch
            let cues: [[String: Any]] = track.cueMarkersS.filter { $0 < duration }.map { at in
                let index = min(n - 1, Int(Double(at) / Double(duration) * Double(n)))
                let feeling = exp.feelings.isEmpty ? Feeling.gratitude : exp.feelings[index]
                return ["at": at, "feeling": feeling.rawValue, "durations": onFirst(custom ?? feeling.touch)]
            }
            return ["id": exp.id.uuidString, "title": exp.title, "feelings": exp.feelings.map(\.rawValue),
                    "durationS": duration, "cues": cues]
        }
        let rems: [[String: Any]] = events.map { event in
            let exp = experiences.first { $0.id == event.experienceID }
            let text = ReminderScheduler.cueText(feeling: event.feeling, experience: exp)
            var r: [String: Any] = ["id": event.id.uuidString, "at": event.scheduledAt.timeIntervalSince1970 * 1000,
                                    "title": text.title, "body": text.body, "feeling": event.feeling.rawValue,
                                    "durations": onFirst(exp?.touchSequence ?? event.feeling.touch)]
            if let exp { r["experienceID"] = exp.id.uuidString }
            return r
        }
        // The watch only delivers reminders while it has taken them over.
        let payload: [String: Any] = ["type": "sync", "experiences": exps, "reminders": takesOverReminders ? rems : [],
                                      "syncedAt": now.timeIntervalSince1970 * 1000]
        do {
            try WCSession.default.updateApplicationContext(payload)
            lastSyncAt = now
        } catch {
            lastError = error.localizedDescription
        }
    }

    fileprivate func received(_ payload: [String: Any]) {
        guard payload["type"] as? String == "startExperience",
              let raw = payload["id"] as? String, let id = UUID(uuidString: raw) else { return }
        onStartExperience?(id)
    }

    var isSupported: Bool { WCSession.isSupported() }
    /// The watch is in use and can play a touch right now.
    var available: Bool { useWatch && isReachable }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends a touch to the watch (routing is decided by `RingHapticsService`). `force` skips the
    /// "Use a watch" switch, for the test button. Returns whether it was sent.
    @discardableResult
    func play(_ pattern: TouchPattern, force: Bool = false) -> Bool {
        guard WCSession.isSupported(), isReachable, force || useWatch else { return false }
        // The watch expects on/off/on…; a pattern that starts with a pause gets a 0 ms "on" first.
        let durations = pattern.startsWithVibration ? pattern.durationsMs : [0] + pattern.durationsMs
        let message: [String: Any] = [
            "type": "play",
            "pattern": ["id": pattern.id, "name": pattern.name, "durations_ms": durations] as [String: Any],
        ]
        WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
            let text = error.localizedDescription
            Task { @MainActor in self?.lastError = text }
        }
        lastSentAt = Date()
        lastError = nil
        return true
    }

    fileprivate func update(paired: Bool, installed: Bool, reachable: Bool) {
        let changed = paired != isPaired || installed != isAppInstalled
        isPaired = paired
        isAppInstalled = installed
        isReachable = reachable
        // Watch app installed or removed: who delivers reminders may have changed (that also syncs).
        // Otherwise sync anyway: the session may only now be activated.
        if changed { rebuildReminders() } else { sync() }
    }

    /// One line for the Ring tab.
    var statusText: String {
        if !isSupported { return "This iPhone can't pair a watch" }
        if !isPaired { return "No Apple Watch paired" }
        if !isAppInstalled { return "Install Kinnora on your Apple Watch" }
        if !isReachable { return "Open Kinnora on your watch to feel touches there" }
        return "Ready · touches play on your wrist"
    }
}

extension WatchLink: WCSessionDelegate {
    private nonisolated func push(_ session: WCSession) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled, reachable = session.isReachable
        Task { @MainActor in self.update(paired: paired, installed: installed, reachable: reachable) }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        push(session)
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { push(session) }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { push(session) }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let id = message["id"] as? String, type = message["type"] as? String
        Task { @MainActor in self.received(["type": type as Any, "id": id as Any]) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let id = userInfo["id"] as? String, type = userInfo["type"] as? String
        Task { @MainActor in self.received(["type": type as Any, "id": id as Any]) }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching watches: activate again for the new one.
        session.activate()
    }
}
