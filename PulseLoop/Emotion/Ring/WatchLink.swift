import Foundation
import Observation
import WatchConnectivity

/// Where touches play. Stored per phone; "Both" is the default so a paired watch just works.
enum TouchTarget: String, CaseIterable, Identifiable {
    case ring, watch, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ring: "Ring"
        case .watch: "Watch"
        case .both: "Both"
        }
    }
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

    var target: TouchTarget = TouchTarget(rawValue: UserDefaults.standard.string(forKey: WatchLink.targetKey) ?? "") ?? .both {
        didSet { UserDefaults.standard.set(target.rawValue, forKey: Self.targetKey) }
    }

    var isSupported: Bool { WCSession.isSupported() }
    /// The watch can play a touch right now and the setting wants it there.
    var canPlay: Bool { target != .ring && isReachable }
    /// Touches should skip the ring: the person chose "Watch" and the watch is there to take them.
    var replacesRing: Bool { target == .watch && isReachable }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends a touch to the watch. `force` ignores the setting (the "Test watch" button).
    /// Returns whether it was sent.
    @discardableResult
    func play(_ pattern: TouchPattern, force: Bool = false) -> Bool {
        guard WCSession.isSupported(), isReachable, force || target != .ring else { return false }
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
        isPaired = paired
        isAppInstalled = installed
        isReachable = reachable
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
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching watches: activate again for the new one.
        session.activate()
    }
}
