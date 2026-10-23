import Foundation
import Observation
import SwiftData

/// App-lifetime services for the emotion app, injected into the SwiftUI environment.
@MainActor
@Observable
final class EmotionServices {
    let client: RingBLEClient
    let coordinator: RingSyncCoordinator
    let simulator: SimulatedRing
    let haptics: RingHapticsService
    let heart: LiveHeartRate
    private(set) var dispatcher: CueDispatcher?
    private(set) var calm: CalmCueMonitor?

    init(client: RingBLEClient, coordinator: RingSyncCoordinator) {
        self.client = client
        self.coordinator = coordinator
        let simulator = SimulatedRing()
        #if targetEnvironment(simulator)
        // No Bluetooth on the Simulator: default to the simulated ring the first time.
        if UserDefaults.standard.object(forKey: "emotion.simulatedRing.enabled") == nil { simulator.isEnabled = true }
        #endif
        self.simulator = simulator
        self.haptics = RingHapticsService(client: client, simulator: simulator)
        self.heart = LiveHeartRate(client: client, coordinator: coordinator, simulator: simulator)
    }

    func playback(for experience: Experience) -> ExperiencePlayback {
        let custom = experience.customTouchData == nil ? nil : experience.touch
        let p = ExperiencePlayback(track: experience.track, feelings: experience.feelings, haptics: haptics, singleTouchOverride: custom)
        p.slideCount = max(1, experience.slides.isEmpty ? 6 : experience.slides.count)
        p.autoCues = experience.cueAuto
        return p
    }

    func playback(feeling: Feeling, track: MusicTrack) -> ExperiencePlayback {
        ExperiencePlayback(track: track, feelings: [feeling], haptics: haptics)
    }

    /// Start sending reminder cues to the ring and register the background refresh.
    /// Call from the app's init (BGTaskScheduler registration must happen before launch ends).
    func startReminderDelivery(context: ModelContext) {
        guard dispatcher == nil else { return }
        let d = CueDispatcher(context: context, services: self)
        dispatcher = d
        calm = CalmCueMonitor(context: context, services: self)
        d.start()
        ReminderBackgroundRefresh.register { [weak d] in
            ReminderScheduler.rebuild(context: context)
            d?.check(.backgroundRefresh)
        }
        ReminderBackgroundRefresh.schedule()
    }

    /// Debug builds can switch back to the original PulseLoop UI.
    static let legacyUIKey = "emotion.legacyPulseLoopUI"
}
