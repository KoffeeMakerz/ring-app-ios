import Foundation
import Observation

/// The only place in the app that makes a ring vibrate. Turns a `TouchPattern` into timed buzz
/// commands for whichever ring is active (simulated or real), clamping gaps to what that ring can do.
@MainActor
@Observable
final class RingHapticsService {
    private let client: RingBLEClient
    let simulator: SimulatedRing

    private(set) var isPlaying = false
    private(set) var lastPlayed: TouchPattern?
    private var playTask: Task<Void, Never>?

    init(client: RingBLEClient, simulator: SimulatedRing) {
        self.client = client
        self.simulator = simulator
    }

    var usesSimulator: Bool { simulator.isEnabled }

    var isRingConnected: Bool { usesSimulator ? simulator.connected : client.state == .connected }

    /// What kind of ring it is: the model ("Colmi R09"), else the family, else the ring's own name.
    var ringName: String {
        if usesSimulator { return "Simulated ring" }
        return client.activeWearableModel?.displayName
            ?? client.activeDeviceType?.displayName
            ?? client.connectedDeviceName
            ?? "Your ring"
    }

    /// The ring's own Bluetooth name, shown small under `ringName` when it adds something.
    var ringDeviceName: String? {
        guard !usesSimulator, let name = client.connectedDeviceName, name != ringName else { return nil }
        return name
    }

    var batteryPercent: Int? { usesSimulator ? simulator.batteryPercent : client.batteryPercent }

    var profile: RingCapabilityProfile {
        usesSimulator ? simulator.profile : RingCapabilityProfile.forFamily(client.activeDeviceType)
    }

    /// The pulses that will actually be sent, after clamping to the ring's minimum gap and fixed buzz length.
    func plan(_ pattern: TouchPattern, profile: RingCapabilityProfile) -> [(start: Int, length: Int, clampedFrom: Int?)] {
        var result: [(start: Int, length: Int, clampedFrom: Int?)] = []
        var lastStart = Int.min / 2
        var shift = 0
        for pulse in pattern.pulses {
            var start = pulse.start + shift
            var clamped: Int? = nil
            if let fixed = profile.buzzMs, start - lastStart < profile.minGapMs, !result.isEmpty {
                clamped = start - lastStart
                let newStart = lastStart + max(profile.minGapMs, fixed)
                shift += newStart - start
                start = newStart
            }
            result.append((start, profile.buzzMs ?? pulse.length, clamped))
            lastStart = start
        }
        return result
    }

    func play(_ pattern: TouchPattern) {
        stop(sendStop: false)
        lastPlayed = pattern
        let profile = self.profile
        let steps = plan(pattern, profile: profile)
        isPlaying = true
        if usesSimulator {
            simulator.log("PLAY \(pattern.name) · \(pattern.durationsMs.map(String.init).joined(separator: "/")) ms")
            for step in steps where step.clampedFrom != nil {
                simulator.log("CLAMP gap \(step.clampedFrom!)→\(profile.minGapMs) ms", .info)
            }
        }
        playTask = Task { [weak self] in
            let begin = ContinuousClock.now
            for step in steps {
                guard let self, !Task.isCancelled else { return }
                let due = begin + .milliseconds(step.start)
                try? await Task.sleep(until: due, clock: .continuous)
                if Task.isCancelled { return }
                await self.sendPulse(lengthMs: step.length, label: "BUZZ \(profile.buzzMs == nil ? "motor on \(step.length) ms" : "find-device") @+\(step.start) ms")
            }
            self?.isPlaying = false
        }
    }

    func playSingle() { play(TouchBlock.tap.pattern) }

    func stop(sendStop: Bool = true) {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        if sendStop, usesSimulator { simulator.stop() }
    }

    private func sendPulse(lengthMs: Int, label: String) async {
        if usesSimulator {
            await simulator.buzz(lengthMs: lengthMs, label: label)
        } else {
            guard client.state == .connected else { return }
            // Today every supported family exposes a fixed "find device" buzz; RWfit custom vibration
            // (cmd 0x06 / key 0x13) replaces this once added to the RWfit encoder.
            client.syncEngine?.findDevice()
        }
    }
}
