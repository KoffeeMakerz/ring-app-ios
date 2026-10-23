import WatchKit

/// Plays a touch with the Taptic Engine. watchOS has no free-form vibration, so every motor-on
/// segment becomes one system haptic at the pattern's timing (longer segments a stronger one).
/// The rhythm is kept, like the ring's fixed buzz.
enum HapticPlayer {
    static func play(_ pattern: Pattern) {
        var t = 0
        for (i, ms) in pattern.durationsMs.enumerated() {
            if i % 2 == 0, ms > 0 {
                let kind: WKHapticType = ms >= 600 ? .notification : (ms >= 400 ? .directionUp : .click)
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(t)) {
                    WKInterfaceDevice.current().play(kind)
                }
            }
            t += ms
        }
    }
}
