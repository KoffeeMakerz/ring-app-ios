import WatchKit

/// Plays a touch with the Taptic Engine. watchOS has no free-form vibration, so every motor-on
/// segment becomes one system haptic at the pattern's timing: longer segments get a stronger one.
///
/// Haptics fired too close together can be merged by the system, so taps are kept at least
/// `minGapMs` apart (pushing the rest of the pattern later, like the ring's minimum gap).
/// Not yet tuned on a real watch.
enum HapticPlayer {
    static let minGapMs = 350

    static func play(_ pattern: Pattern) {
        var t = 0
        var lastTap = Int.min / 2
        var shift = 0
        for (i, ms) in pattern.durationsMs.enumerated() {
            if i % 2 == 0, ms > 0 {
                var start = t + shift
                if start - lastTap < minGapMs {
                    shift += lastTap + minGapMs - start
                    start = lastTap + minGapMs
                }
                lastTap = start
                let kind: WKHapticType = ms >= 600 ? .notification : (ms >= 400 ? .directionUp : .click)
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(start)) {
                    WKInterfaceDevice.current().play(kind)
                }
            }
            t += ms
        }
    }
}
