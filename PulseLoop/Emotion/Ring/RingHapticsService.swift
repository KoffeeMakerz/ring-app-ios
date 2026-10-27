import Foundation
import Observation

/// The only place in the app that makes a ring vibrate. Turns a `TouchPattern` into timed buzz
/// commands for whichever ring is active (simulated or real), clamping gaps to what that ring can do.
@MainActor
@Observable
final class RingHapticsService {
    private let client: RingBLEClient
    let simulator: SimulatedRing
    /// The paired Apple Watch, if any. Touches go there too, per the Ring / Watch / Both setting.
    var watch: WatchLink?

    private(set) var isPlaying = false
    private(set) var lastPlayed: TouchPattern?
    private var playTask: Task<Void, Never>?

    init(client: RingBLEClient, simulator: SimulatedRing) {
        self.client = client
        self.simulator = simulator
    }

    var usesSimulator: Bool { simulator.isEnabled }

    var isRingConnected: Bool { usesSimulator ? simulator.connected : client.state == .connected }

    /// Kinnora's "Use a ring" switch (Devices tab). Off: no touches go to the ring, it's disconnected
    /// and never reconnected by itself. Pairing a ring turns it back on.
    var useRing: Bool = RingBLEClient.ringEnabled {
        didSet {
            UserDefaults.standard.set(useRing, forKey: RingBLEClient.ringEnabledKey)
            if useRing { client.connectLastKnown() } else if client.state != .idle { client.disconnect() }
        }
    }
    /// The ring is in use and connected.
    var ringActive: Bool { useRing && isRingConnected }

    /// Where a touch goes now. The ring comes first: with "Ring first", the watch plays only when no
    /// ring is connected; with "Both", both play. With neither, the ring path runs (a no-op).
    func route() -> (ring: Bool, watch: Bool) {
        let ringOK = ringActive
        let watchOK = watch?.available ?? false
        switch watch?.target ?? .ringFirst {
        case .ringFirst: return (ringOK || !watchOK, !ringOK && watchOK)
        case .both: return (true, watchOK)
        }
    }
    /// "ring", "watch", "ring + watch" or "nowhere", for logs.
    var routeLabel: String {
        let r = route()
        let names = [r.ring && ringActive ? "ring" : nil, r.watch ? "watch" : nil].compactMap { $0 }
        return names.isEmpty ? "nowhere" : names.joined(separator: " + ")
    }
    /// A touch can be felt somewhere: on the ring, or on a watch that's listening.
    var canDeliverTouch: Bool { ringActive || (watch?.available ?? false) }

    /// What kind of ring it is: the model ("Colmi R09"), else the family, else the ring's own name.
    var ringName: String {
        if usesSimulator { return "Simulated ring" }
        return RingBLEClient.displayableName(client.activeWearableModel?.displayName)
            ?? RingBLEClient.displayableName(client.activeDeviceType?.displayName)
            ?? client.connectedDeviceName
            ?? "Smart ring"
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

    /// Plays a touch on the ring and, per the setting, on the watch.
    func play(_ pattern: TouchPattern) {
        stop(sendStop: false)
        lastPlayed = pattern
        let routing = route()
        if routing.watch { watch?.play(pattern) }
        // Watch only: skip the ring, but keep the timing so isPlaying matches what the wrist feels.
        let onRing = routing.ring && useRing
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
                guard onRing else { continue }
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
