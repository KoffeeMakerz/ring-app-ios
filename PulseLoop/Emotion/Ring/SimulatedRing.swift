import Foundation
import Observation

/// How a ring family vibrates. Values for real rings are placeholders until the Phase 0 hardware
/// measurements replace them.
struct RingCapabilityProfile: Identifiable, Hashable {
    let id: String
    let name: String
    /// Fixed buzz length for rings that only have a "find device" buzz; nil = arbitrary length.
    let buzzMs: Int?
    let minGapMs: Int
    let supportsStop: Bool
    /// Ring accepts a real vibration command (count / strength / rhythm), e.g. RWfit with
    /// `isSupportVibrationControl`.
    let customVibration: Bool

    static let colmi = RingCapabilityProfile(id: "colmi", name: "Colmi", buzzMs: 300, minGapMs: 600, supportsStop: true, customVibration: false)
    static let ycbt = RingCapabilityProfile(id: "ycbt", name: "R10M", buzzMs: 400, minGapMs: 700, supportsStop: true, customVibration: false)
    static let crp = RingCapabilityProfile(id: "crp", name: "CRP", buzzMs: 500, minGapMs: 800, supportsStop: false, customVibration: false)
    static let rwfit = RingCapabilityProfile(id: "rwfit", name: "RWfit", buzzMs: nil, minGapMs: 100, supportsStop: true, customVibration: true)
    static let all: [RingCapabilityProfile] = [.colmi, .ycbt, .crp, .rwfit]

    static func forFamily(_ type: RingDeviceType?) -> RingCapabilityProfile {
        guard let type else { return .colmi }
        let name = String(describing: type).lowercased()
        if name.contains("rwfit") { return .rwfit }
        if name.contains("ycbt") || name.contains("tk5") { return .ycbt }
        if name.contains("crp") { return .crp }
        return .colmi
    }
}

enum HeartScenario: String, CaseIterable, Identifiable {
    case resting, coherent, tense, workout, noSignal
    var id: String { rawValue }
    var name: String {
        switch self {
        case .resting: "Resting"
        case .coherent: "Coherent breathing"
        case .tense: "Tense, still"
        case .workout: "After workout"
        case .noSignal: "No signal"
        }
    }
    var note: String {
        switch self {
        case .resting: "Steady ~62 bpm, small natural variation."
        case .coherent: "HR rises and falls with a 10 s breath (6/min) — drives the coherence meter."
        case .tense: "Higher HR, very little variation, no movement — for the future calm cue."
        case .workout: "High HR settling down — calm cue must stay silent here."
        case .noSignal: "Ring loose or off the finger — UI must show “no reading”."
        }
    }
    func bpm(atSecond k: Double) -> Double? {
        switch self {
        case .resting: 62 + 1.5 * sin(k * 0.9) + sin(k * 2.3)
        case .coherent: 64 + 6 * sin(k * .pi / 5)
        case .tense: 84 + 0.6 * sin(k * 1.7)
        case .workout: 96 + 28 * exp(-k / 40) + sin(k)
        case .noSignal: nil
        }
    }
}

/// Level-1 ring simulator (debug builds): a fake ring that the whole app can use on the iOS
/// Simulator. Buzz commands light the overlay, vibrate the phone and land in a timestamped log;
/// heart rate comes from a scripted scenario.
@MainActor
@Observable
final class SimulatedRing {
    struct LogLine: Identifiable {
        let id = UUID()
        let time: String
        let text: String
        let kind: Kind
        enum Kind { case info, buzz, warning, error, heart, connect }
    }

    private static let enabledKey = "emotion.simulatedRing.enabled"

    var isEnabled: Bool = UserDefaults.standard.bool(forKey: SimulatedRing.enabledKey) {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey); if isEnabled { connected = true } }
    }
    var connected = true
    var isBuzzing = false
    var profile: RingCapabilityProfile = .colmi
    var scenario: HeartScenario = .coherent { didSet { log("HR scenario \(scenario.rawValue)", .heart) } }
    var extraDelayMs = 0
    var dropOneInFive = false
    var lowBattery = false
    var mirrorToPhoneHaptics = true
    var showOverlay = true
    private(set) var entries: [LogLine] = []
    private(set) var currentBPM: Int?

    private var sent = 0
    private let start = Date()
    private var hrTask: Task<Void, Never>?
    private var hrSecond: Double = 0

    var batteryPercent: Int { lowBattery ? 9 : 82 }

    init() {
        log("CONNECT SimulatedRing (\(profile.name) profile)", .connect)
        startHeartStream()
    }

    func setConnected(_ value: Bool) {
        connected = value
        isBuzzing = false
        log(value ? "CONNECT restored" : "DISCONNECT (simulated)", value ? .connect : .error)
    }

    /// Called by `RingHapticsService` for every motor-on pulse. Returns false when the command is rejected/dropped.
    @discardableResult
    func buzz(lengthMs: Int, label: String) async -> Bool {
        guard connected else { log("REJECTED ring disconnected", .error); return false }
        if extraDelayMs > 0 { try? await Task.sleep(for: .milliseconds(extraDelayMs)) }
        sent += 1
        if dropOneInFive, sent % 5 == 0 { log("DROPPED \(label)", .error); return false }
        log(label, .buzz)
        isBuzzing = true
        if mirrorToPhoneHaptics { PhoneHaptics.buzz(lengthMs: lengthMs) }
        try? await Task.sleep(for: .milliseconds(lengthMs))
        isBuzzing = false
        return true
    }

    func stop() {
        isBuzzing = false
        log(profile.supportsStop ? "STOP sent" : "STOP not supported on this profile", profile.supportsStop ? .info : .warning)
    }

    func log(_ text: String, _ kind: LogLine.Kind = .info) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let time = String(format: "%02d:%02d.%03d", ms / 60000, (ms / 1000) % 60, ms % 1000)
        entries.insert(LogLine(time: time, text: text, kind: kind), at: 0)
        if entries.count > 200 { entries.removeLast(entries.count - 200) }
    }

    func clearLog() { entries.removeAll() }

    private func startHeartStream() {
        hrTask?.cancel()
        hrTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.hrSecond += 1
                if self.connected, let v = self.scenario.bpm(atSecond: self.hrSecond) {
                    self.currentBPM = Int(v.rounded())
                } else {
                    self.currentBPM = nil
                }
            }
        }
    }
}
