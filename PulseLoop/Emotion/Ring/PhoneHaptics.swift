import CoreHaptics
import UIKit

/// Phone-side vibration used to mirror simulated ring buzzes (and as a fallback cue).
enum PhoneHaptics {
    private static var engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        return engine
    }()

    static func buzz(lengthMs: Int, intensity: Float = 0.8) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        do {
            try engine.start()
            let event = CHHapticEvent(eventType: .hapticContinuous,
                                      parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)],
                                      relativeTime: 0, duration: Double(lengthMs) / 1000)
            let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}
