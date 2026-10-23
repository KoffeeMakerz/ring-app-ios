import Foundation
import WatchConnectivity

/// A touch: alternating on / off ms, starting with on (the format the iPhone sends).
struct Pattern {
    let name: String
    let durationsMs: [Int]

    init(name: String, durationsMs: [Int]) {
        self.name = name
        self.durationsMs = durationsMs
    }

    init(dict: [String: Any]) {
        name = dict["name"] as? String ?? ""
        durationsMs = (dict["durations_ms"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
    }

    /// The iPhone's reminder notifications carry the feeling (`"feeling": "gratitude"`).
    init?(reminderInfo: [AnyHashable: Any]) {
        guard let raw = reminderInfo["feeling"] as? String,
              let match = Self.feelings.first(where: { $0.0.lowercased() == raw }) else { return nil }
        self.init(name: match.0, durationsMs: match.1)
    }

    /// Same patterns as the iPhone app (`Feeling.durationsMs`).
    static let feelings: [(String, [Int])] = [
        ("Gratitude", [350, 300, 350, 1200, 350, 300, 350, 1200, 500]),
        ("Love", [300, 300, 450, 1000, 300, 300, 450, 1000, 300, 300, 450]),
        ("Joy", [250, 350, 250, 350, 250, 900, 250, 350, 250, 350, 250, 900, 250, 350, 250, 350, 250]),
        ("Bliss", [300, 1300, 300, 1000, 300, 750, 300, 550, 700]),
        ("Calm", [700, 1300, 700, 1300, 700, 1300, 700]),
        ("Confidence", [450, 900, 450, 900, 300, 300, 300, 300, 600]),
    ]
}

/// Receives touches from the iPhone and plays them.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    /// The last touch felt, for the screen.
    @Published var lastTouch: (name: String, at: Date)?
    @Published var phoneReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.phoneReachable = reachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.phoneReachable = reachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }

    private func handle(_ payload: [String: Any]) {
        guard payload["type"] as? String == "play", let dict = payload["pattern"] as? [String: Any] else { return }
        let pattern = Pattern(dict: dict)
        DispatchQueue.main.async {
            HapticPlayer.play(pattern)
            self.lastTouch = (pattern.name, Date())
        }
    }
}
