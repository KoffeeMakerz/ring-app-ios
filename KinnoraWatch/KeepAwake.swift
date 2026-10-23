import Foundation
import WatchKit

/// Keeps the watch app running with the wrist down for up to an hour (a mindfulness session), so
/// touches sent by the iPhone during practice or an experience still arrive. watchOS only delivers
/// live messages to a running app.
///
/// Needs the watch target's Background Modes → "Mindfulness" (Info.plist `WKBackgroundModes` = `mindfulness`).
final class KeepAwake: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    static let shared = KeepAwake()

    @Published private(set) var isOn = false
    @Published private(set) var endsAt: Date?
    private var session: WKExtendedRuntimeSession?

    func toggle() { isOn ? stop() : start() }

    func start() {
        guard session == nil else { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        session = s
    }

    func stop() {
        session?.invalidate()
        session = nil
        isOn = false
        endsAt = nil
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async {
            self.isOn = true
            self.endsAt = extendedRuntimeSession.expirationDate
        }
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        WKInterfaceDevice.current().play(.stop)
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        DispatchQueue.main.async {
            self.session = nil
            self.isOn = false
            self.endsAt = nil
        }
    }
}
