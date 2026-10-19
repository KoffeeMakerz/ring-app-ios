import Foundation
import Observation

enum CoherenceLevel: Int, Comparable {
    case low, medium, high
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    var name: String { ["Low", "Medium", "High"][rawValue] }
}

/// Live heart rate for meditation, from the simulated ring or the real ring's live HR stream.
/// Coherence is an *estimate*: how strongly HR rises and falls with the paced breath (~1 sample/s,
/// no beat-to-beat data on these rings).
@MainActor
@Observable
final class LiveHeartRate {
    private let coordinator: RingSyncCoordinator
    private let simulator: SimulatedRing
    private(set) var samples: [Int] = []
    private(set) var isRunning = false
    private var task: Task<Void, Never>?

    init(coordinator: RingSyncCoordinator, simulator: SimulatedRing) {
        self.coordinator = coordinator
        self.simulator = simulator
    }

    var current: Int? { samples.last }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        samples = []
        if simulator.isEnabled {
            task = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self else { return }
                    if let bpm = self.simulator.currentBPM { self.append(bpm) }
                }
            }
        } else {
            coordinator.startWorkoutHeartRate()
            task = Task { [weak self] in
                let stream = await PulseEventBus.shared.stream()
                for await event in stream {
                    if Task.isCancelled { break }
                    if case let .heartRateSample(bpm, _) = event { self?.append(bpm) }
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if isRunning, !simulator.isEnabled { coordinator.stopWorkoutHeartRate() }
        isRunning = false
    }

    private func append(_ bpm: Int) {
        guard bpm > 30, bpm < 220 else { return }
        samples.append(bpm)
        if samples.count > 600 { samples.removeFirst(samples.count - 600) }
    }

    /// Amplitude of the breath-linked HR swing over the last ~30 s.
    func coherence(breathPeriodS: Double = 10) -> CoherenceLevel? {
        guard samples.count >= 20 else { return nil }
        let window = Array(samples.suffix(30)).map(Double.init)
        let period = max(4, Int(breathPeriodS))
        var swings: [Double] = []
        var i = 0
        while i + period <= window.count {
            let slice = window[i..<(i + period)]
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
