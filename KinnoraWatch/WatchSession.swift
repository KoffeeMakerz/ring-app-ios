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
}

/// The link to the Kinnora iPhone app:
/// - receives touches to play (`"play"`) and the synced experiences and reminder plan (`"sync"`,
///   as application context, which arrives even when this app wasn't running);
/// - asks the iPhone to start an experience (`"startExperience"`).
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
        let context = session.receivedApplicationContext
        if !context.isEmpty { handle(context) }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.phoneReachable = reachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { handle(message) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { handle(userInfo) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { handle(applicationContext) }

    private func handle(_ payload: [String: Any]) {
        switch payload["type"] as? String {
        case "play":
            guard let dict = payload["pattern"] as? [String: Any] else { return }
            let pattern = Pattern(dict: dict)
            DispatchQueue.main.async {
                HapticPlayer.play(pattern)
                self.lastTouch = (pattern.name, Date())
            }
        case "sync":
            WatchStore.shared.apply(payload)
        default:
            break
        }
    }

    /// Asks the iPhone to play an experience (music and images there). Queued if the phone is out
    /// of reach, so it starts when the phone next hears from the watch.
    /// Returns true when the phone got it right away.
    @discardableResult
    func startOnPhone(experienceID: String) -> Bool {
        guard WCSession.isSupported() else { return false }
        let message: [String: Any] = ["type": "startExperience", "id": experienceID]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
            return true
        }
        WCSession.default.transferUserInfo(message)
        return false
    }
}
