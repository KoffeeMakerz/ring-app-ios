import Foundation
import Observation

/// App-lifetime services for the emotion app, injected into the SwiftUI environment.
@MainActor
@Observable
final class EmotionServices {
    let client: RingBLEClient
    let coordinator: RingSyncCoordinator
    let simulator: SimulatedRing
    let haptics: RingHapticsService
    let heart: LiveHeartRate

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
        self.heart = LiveHeartRate(coordinator: coordinator, simulator: simulator)
    }

    func playback(for experience: Experience) -> ExperiencePlayback {
        let p = ExperiencePlayback(track: experience.track, touch: experience.touch, haptics: haptics)
        p.slideCount = max(1, experience.photoIdentifiers.count > 0 ? experience.photoIdentifiers.count : 6)
        p.autoCues = experience.cueAuto
        return p
    }

    func playback(feeling: Feeling, track: MusicTrack) -> ExperiencePlayback {
        ExperiencePlayback(track: track, touch: feeling.touch, haptics: haptics)
    }

    /// Debug builds can switch back to the original PulseLoop UI.
    static let legacyUIKey = "emotion.legacyPulseLoopUI"
}
