import Foundation
import Observation

enum CoherenceLevel: Int, Comparable {
    case low, medium, high
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    var name: String { ["Low", "Medium", "High"][rawValue] }
}

/// Live heart rate for meditation, from the simulated ring or the real ring's live HR stream.
/// Coherence is an *estimate*: how strongly HR rises and falls with the paced breath. These rings
/// send HR roughly once a second at best (often less, and irregularly), with no beat-to-beat data,
/// so everything here works on time, not on sample counts.
@MainActor
@Observable
final class LiveHeartRate {
    enum Status: Equatable {
        case idle          // not started (feature off)
        case noRing        // real-ring mode but nothing connected
        case starting      // connected, waiting for the first sample (rings need ~10–20 s)
        case live          // samples arriving
        case stalled       // had or expected samples, none for a while
    }

    private let client: RingBLEClient
    private let coordinator: RingSyncCoordinator
    private let simulator: SimulatedRing
    /// Recent HR values for the sparkline (one entry per received sample).
    private(set) var samples: [Int] = []
    private var timed: [(t: Date, bpm: Int)] = []
    private(set) var isRunning = false
    private(set) var startedAt: Date?
    private(set) var lastSampleAt: Date?
    private var lastRestartAt: Date?
    private var task: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    /// Forces SwiftUI to re-read `status` once a second (it depends on the clock).
    private(set) var tick = 0

    init(client: RingBLEClient, coordinator: RingSyncCoordinator, simulator: SimulatedRing) {
        self.client = client
        self.coordinator = coordinator
        self.simulator = simulator
    }

    var current: Int? { samples.last }
    var usingSimulator: Bool { simulator.isEnabled }
    var ringConnected: Bool { simulator.isEnabled ? simulator.connected : client.state == .connected }

    var status: Status {
        _ = tick
        guard isRunning else { return .idle }
        if !ringConnected { return .noRing }
        let now = Date()
        if let last = lastSampleAt {
            return now.timeIntervalSince(last) > 12 ? .stalled : .live
        }
        if let s = startedAt, now.timeIntervalSince(s) > 30 { return .stalled }
        return .starting
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        samples = []; timed = []
        startedAt = Date(); lastSampleAt = nil; lastRestartAt = nil
        if simulator.isEnabled {
            task = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self else { return }
                    if let bpm = self.simulator.currentBPM { self.append(bpm) }
                }
            }
        } else {
            // Records the intent even while disconnected; the coordinator re-issues the live stream
            // when the ring (re)connects.
            coordinator.startWorkoutHeartRate()
            task = Task { [weak self] in
                let stream = await PulseEventBus.shared.stream()
                for await event in stream {
                    if Task.isCancelled { break }
                    if case let .heartRateSample(bpm, _) = event { self?.append(bpm) }
                }
            }
        }
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick &+= 1
                self.restartIfStalled()
            }
        }
    }

    func stop() {
        task?.cancel(); task = nil
        watchdog?.cancel(); watchdog = nil
        if isRunning, !simulator.isEnabled { coordinator.stopWorkoutHeartRate() }
        isRunning = false
    }

    /// Real rings sometimes stop streaming (firmware timeout, brief disconnect). Nudge the stream.
    private func restartIfStalled() {
        guard !simulator.isEnabled, client.state == .connected, status == .stalled else { return }
        if let r = lastRestartAt, Date().timeIntervalSince(r) < 15 { return }
        lastRestartAt = Date()
        coordinator.startWorkoutHeartRate()
    }

    private func append(_ bpm: Int) {
        guard bpm > 30, bpm < 220 else { return }
        let now = Date()
        samples.append(bpm)
        timed.append((now, bpm))
        lastSampleAt = now
        if samples.count > 600 { samples.removeFirst(samples.count - 600) }
        timed.removeAll { now.timeIntervalSince($0.t) > 120 }
    }

    /// Timed samples from the last `seconds` (up to 120 s), for the heart rhythm chart.
    func recent(seconds: Double) -> [(t: Date, bpm: Int)] {
        let now = Date()
        return timed.filter { now.timeIntervalSince($0.t) <= seconds }
    }

    /// Seconds of usable heart data in the coherence window, for "measuring…" progress.
    var secondsOfData: Int {
        guard let first = timed.first?.t, let last = timed.last?.t else { return 0 }
        return Int(last.timeIntervalSince(first))
    }

    /// Amplitude of the breath-linked HR swing over the last ~30 s, resampled to 1 Hz.
    func coherence(breathPeriodS: Double = 10) -> CoherenceLevel? {
        let now = Date()
        let window = timed.filter { now.timeIntervalSince($0.t) <= 30 }
        guard window.count >= 6, let first = window.first?.t,
              now.timeIntervalSince(first) >= 20,
              let lastAt = lastSampleAt, now.timeIntervalSince(lastAt) <= 12 else { return nil }
        // Forward-fill to one value per second so irregular sample rates don't skew the swing.
        var series: [Double] = []
        var idx = 0
        var value = Double(window[0].bpm)
        var t = first
        while t <= now {
            while idx < window.count, window[idx].t <= t { value = Double(window[idx].bpm); idx += 1 }
            series.append(value)
            t = t.addingTimeInterval(1)
        }
        let period = max(4, Int(breathPeriodS.rounded()))
        var swings: [Double] = []
        var i = 0
        while i + period <= series.count {
            let slice = series[i..<(i + period)]
            swings.append((slice.max() ?? 0) - (slice.min() ?? 0))
            i += period
        }
        guard !swings.isEmpty else { return nil }
        let swing = swings.reduce(0, +) / Double(swings.count)
        switch swing {
        case ..<3: return .low
        case ..<7: return .medium
        default: return .high
        }
    }
}
