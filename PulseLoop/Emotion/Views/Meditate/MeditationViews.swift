import SwiftData
import SwiftUI

/// 4.3 Meditate.
struct MeditateSelectView: View {
    @Environment(EmotionRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var profiles: [EmotionProfile]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Meditate").font(EFont.display(28)).padding(.top, 8)
                Button { router.meditation = .journey } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("FULL JOURNEY · 15 MIN").font(EFont.label).tracking(1.2).foregroundStyle(Color(hex: "#7FB2F0"))
                        Text(MeditationKind.journey.title).font(EFont.display(22)).padding(.top, 6).padding(.bottom, 16)
                        PhaseStrip(kind: .journey, activeIndex: nil, activeFraction: 0)
                        HStack(spacing: 0) {
                            ForEach(Array(MeditationKind.journey.phases.enumerated()), id: \.offset) { _, ph in
                                Text("\(ph.name.components(separatedBy: " ").first ?? ph.name) \(ph.seconds / 60)'").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading).eCard(Color(hex: "#15233A"), radius: 24)
                }
                .buttonStyle(.plain)
                HStack(spacing: 10) {
                    sessionTile(.relax, icon: "moon", color: Color(hex: "#B892FF"), meta: "Body scan · 10 min")
                    sessionTile(.coherence, icon: "water.waves", color: Color(hex: "#7FB2F0"), meta: "Paced breathing · 5 min")
                }
                SectionLabel("Session settings").padding(.top, 4)
                if let p = profiles.first {
                    @Bindable var profile = p
                    VStack(spacing: 0) {
                        HStack {
                            Text("Breathing pace").font(EFont.body(15, .semibold))
                            Spacer()
                            Menu {
                                Button("4 in · 7 out (calming)") { profile.breathInSeconds = 4; profile.breathOutSeconds = 7 }
                                Button("5 in · 5 out (6/min)") { profile.breathInSeconds = 5; profile.breathOutSeconds = 5 }
                                Button("5.5 in · 5.5 out (5.5/min)") { profile.breathInSeconds = 5.5; profile.breathOutSeconds = 5.5 }
                            } label: {
                                Text("\(fmt(profile.breathInSeconds)) in · \(fmt(profile.breathOutSeconds)) out").font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                            }
                        }
                        .frame(minHeight: 56)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Ring guides my breath", subtitle: "A gentle tap every third in-breath, so eyes can close. Never during coherence.", isOn: $profile.ringGuidesBreath)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Heart rhythm chart", subtitle: "Optional · HRV and coherence from the ring's heart rate", isOn: $profile.liveHeartFeedback)
                    }
                    .padding(.horizontal, 16).eCard()
                    .onChange(of: profile.ringGuidesBreath) { try? context.save() }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    private func sessionTile(_ kind: MeditationKind, icon: String, color: Color, meta: String) -> some View {
        Button { router.meditation = kind } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color)
                Text(kind.title).font(EFont.body(16, .bold)).padding(.top, 4)
                Text(meta).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
        }
        .buttonStyle(.plain)
    }
}

struct PhaseStrip: View {
    let kind: MeditationKind
    let activeIndex: Int?
    let activeFraction: Double
    var body: some View {
        GeometryReader { geo in
            let total = Double(kind.totalSeconds)
            let gaps = CGFloat(kind.phases.count - 1) * 4
            HStack(spacing: 4) {
                ForEach(Array(kind.phases.enumerated()), id: \.offset) { i, ph in
                    let w = (geo.size.width - gaps) * CGFloat(Double(ph.seconds) / total)
                    ZStack(alignment: .leading) {
                        Capsule().fill(i == kind.phases.count - 1 && kind == .journey ? EColor.accent.opacity(activeIndex == nil ? 1 : 0.25) : Color(hex: "#7FB2F0").opacity(activeIndex == nil ? (i == 0 ? 0.55 : 1) : 0.25))
                        if let a = activeIndex, i <= a {
                            Capsule().fill(Color(hex: "#7FB2F0")).frame(width: i < a ? w : w * activeFraction)
                        }
                    }
                    .frame(width: w)
                }
            }
        }
        .frame(height: 8)
    }
}

/// 4.4 Session player: phases, breath pacer (+ a ring tap every third in-breath, none in coherence), live coherence estimate.
struct MeditationSessionView: View {
    let kind: MeditationKind
    @Environment(EmotionServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [EmotionProfile]

    @State private var elapsed = 0
    @State private var running = true
    @State private var inhale = true
    @State private var phaseSecondsLeft = 0.0
    @AppStorage("emotion.showHeartChart") private var showHeart = true
    /// When each in-breath started, to draw the breath bands on the heart chart.
    @State private var inhaleStarts: [Date] = []
    @State private var breathCount = 0
    /// Ring guidance taps only every few breaths (frequent taps were too much), and never during
    /// coherence breathing, where the person follows the circle and their own rhythm.
    static let ringTapEveryBreaths = 3
    @State private var coherence: [CoherenceLevel: Int] = [:]
    @State private var hrStart: Int?
    @State private var finished = false
    @State private var feelAfter: String?
    @State private var showPairing = false
    @State private var hrvBefore: Int?
    @State private var hrvAfter: Int?
    @State private var measuringHRV = false

    private var profile: EmotionProfile? { profiles.first }
    // The calm cue's short session always uses 4 in / 7 out.
    private var inS: Double { kind == .calmBreath ? 4 : profile?.breathInSeconds ?? 4 }
    private var outS: Double { kind == .calmBreath ? 7 : profile?.breathOutSeconds ?? 7 }

    private var phaseIndex: Int {
        var t = 0
        for (i, ph) in kind.phases.enumerated() { t += ph.seconds; if elapsed < t { return i } }
        return kind.phases.count - 1
    }
    private var phaseFraction: Double {
        let before = kind.phases.prefix(phaseIndex).map(\.seconds).reduce(0, +)
        return Double(elapsed - before) / Double(kind.phases[phaseIndex].seconds)
    }
    private var phaseName: String { kind.phases[phaseIndex].name }
    private var isBreathingPhase: Bool { phaseName.lowercased().contains("breathing") }

    var body: some View {
        Group { if finished { summary } else { session } }
            .onAppear {
                if profile?.liveHeartFeedback ?? true { services.heart.start() }
                hrvBefore = latestHRV(within: 6 * 3600)
            }
            .onDisappear { services.heart.stop(); services.haptics.stop(sendStop: false) }
            .sheet(isPresented: $showPairing) {
                PairingView(onConnected: { showPairing = false }, onSkip: { showPairing = false })
            }
    }

    private var session: some View {
        VStack(spacing: 0) {
            HStack {
                Button { finish() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("End session")
                Spacer()
                Text("\(timeString(Double(kind.totalSeconds - elapsed))) left").font(EFont.body(14, .semibold)).foregroundStyle(EColor.textSecondary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            PhaseStrip(kind: kind, activeIndex: phaseIndex, activeFraction: phaseFraction).padding(.top, 8)
            Text("PHASE \(phaseIndex + 1) · \(phaseName.uppercased())").font(EFont.label).tracking(1.2).foregroundStyle(Color(hex: "#7FB2F0")).padding(.top, 10)
            Spacer()
            // Near-white so it stays clear over any background image.
            ZStack {
                Circle().stroke(.white.opacity(0.55), lineWidth: 1.5).frame(width: 240, height: 240)
                Circle().fill(Color(hex: "#EEF4FF").opacity(0.9)).frame(width: 190, height: 190)
                    .shadow(color: .white.opacity(0.45), radius: 18)
                    .scaleEffect(isBreathingPhase ? (inhale ? 1.12 : 0.78) : 1)
                    .animation(.easeInOut(duration: inhale ? inS : outS), value: inhale)
                VStack(spacing: 4) {
                    Text(isBreathingPhase ? (inhale ? "Breathe in" : "Breathe out") : (phaseName == "Reflect" ? "Reflect" : "Let go")).font(EFont.display(26))
                    Text(isBreathingPhase ? "\(Int(phaseSecondsLeft.rounded(.up)))" : (phaseName == "Reflect" ? "What do you feel now?" : "Soften from head to toe")).font(EFont.body(15, .semibold))
                }
                .foregroundStyle(EColor.calmGround)
                .multilineTextAlignment(.center)
                .frame(width: 160)
            }
            .frame(height: 300)
            Spacer()
            if showHeart { heartPanel }
            Spacer(minLength: 16)
            HStack(spacing: 28) {
                Button { showHeart.toggle() } label: {
                    Image(systemName: showHeart ? "waveform.path.ecg" : "eye.slash").frame(width: 52, height: 52)
                        .background(showHeart ? Color(hex: "#7FB2F0").opacity(0.3) : EColor.calmCard, in: Circle())
                }
                .accessibilityLabel(showHeart ? "Hide heart rhythm chart" : "Show heart rhythm chart")
                Button { running.toggle() } label: {
                    Image(systemName: running ? "pause.fill" : "play.fill").font(.system(size: 26)).foregroundStyle(EColor.calmGround)
                        .frame(width: 72, height: 72).background(Color(hex: "#7FB2F0"), in: Circle())
                }
                .accessibilityLabel(running ? "Pause" : "Resume")
                Button { finish() } label: { Image(systemName: "checkmark").frame(width: 52, height: 52).background(EColor.calmCard, in: Circle()) }
                    .accessibilityLabel("Finish session")
            }
            .foregroundStyle(EColor.text)
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
        .background { CalmBackdrop(names: CalmImages.names(for: kind), index: elapsed / CalmImages.secondsPerImage) }
        .emotionScreen(EColor.calmGround)
        .task { await runClock() }
    }

    @ViewBuilder
    private var heartPanel: some View {
        let heartOn = profile?.liveHeartFeedback ?? true
        if !heartOn {
            heartNotice(icon: "heart.slash", title: "Live heart feedback is off",
                        text: "Turn it on to see your heart rhythm and coherence from the ring.",
                        action: "Turn on") {
                profile?.liveHeartFeedback = true
                try? context.save()
                services.heart.start()
            }
        } else {
            liveHeartPanel
        }
    }

    private func heartNotice(icon: String, title: String, text: String, action: String?, onAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Color(hex: "#7FB2F0")).frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(EFont.body(15, .bold))
                Text(text).font(EFont.body(13)).foregroundStyle(EColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action, action: onAction)
                        .font(EFont.body(14, .bold)).foregroundStyle(EColor.calmGround)
                        .padding(.horizontal, 16).frame(height: 36).background(Color(hex: "#7FB2F0"), in: Capsule())
                        .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard(EColor.calmCard, radius: 22)
    }

    /// Heart rhythm (HRV) chart: heart rate over the last minute with the in-breaths shaded, plus
    /// the coherence estimate during paced breathing. Shows its status inline when there's no pulse.
    private var liveHeartPanel: some View {
        let level = services.heart.coherence(breathPeriodS: inS + outS)
        let status = services.heart.status
        let stalled = status == .stalled
        let points = services.heart.recent(seconds: 60)
        let message: String? = {
            switch status {
            case .noRing: return "Connect your ring to see your heart rhythm. The breathing guide works without it."
            case .starting: return "Starting… keep your hand still. The first reading takes 10–20 seconds."
            case .stalled where points.isEmpty: return "No pulse from the ring yet. Make sure it's snug, sensor on the palm side."
            case .idle: return "Starting…"
            default: return points.count < 2 ? "Waiting for heart readings…" : nil
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Heart rhythm · HRV").font(EFont.body(15, .bold))
                Spacer()
                Text(stalled && !points.isEmpty ? "Signal lost · hold still" : services.heart.current.map { "\($0) bpm" } ?? "")
                    .font(EFont.body(12)).foregroundStyle(stalled ? EColor.accent : EColor.textSecondary)
            }
            ZStack {
                HeartRhythmChart(points: points, inhaleStarts: inhaleStarts, inhaleSeconds: inS, window: 60)
                if let message {
                    Text(message).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 12)
                }
            }
            .frame(height: 84)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message ?? "Heart rate trace over the last minute, in-breaths shaded")
            if isBreathingPhase {
                HStack(spacing: 6) {
                    ForEach([CoherenceLevel.low, .medium, .high], id: \.rawValue) { l in
                        Capsule().fill(level == l ? (l == .high ? EColor.accent : l == .medium ? Color(hex: "#7FB2F0") : Color(hex: "#3A4560")) : Color(hex: "#22324D")).frame(height: 8)
                    }
                }
                HStack {
                    Text("Low"); Spacer()
                    Text(level.map { "\($0.name) coherence" } ?? "Measuring… \(min(100, services.heart.secondsOfData * 5))%").fontWeight(.bold).foregroundStyle(EColor.text)
                    Spacer(); Text("High")
                }
                .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            }
            Text("Heart rate rising on the in-breath and falling on the out-breath is coherence. An estimate from your ring's pulse, not a medical reading.")
                .font(EFont.body(11)).foregroundStyle(EColor.textMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).eCard(EColor.calmCard.opacity(0.92), radius: 22)
    }

    private func runClock() async {
        var breathT = 0.0
        while elapsed < kind.totalSeconds && !finished {
            try? await Task.sleep(for: .milliseconds(250))
            guard running else { continue }
            breathT += 0.25
            let cycle = inS + outS
            let pos = breathT.truncatingRemainder(dividingBy: cycle)
            let nowInhale = pos < inS
            if nowInhale != inhale {
                inhale = nowInhale
                if inhale {
                    inhaleStarts.append(Date())
                    inhaleStarts.removeAll { Date().timeIntervalSince($0) > 90 }
                }
                if inhale, isBreathingPhase {
                    breathCount += 1
                    let coherencePhase = phaseName.lowercased().contains("coherence")
                    if !coherencePhase, (breathCount - 1) % Self.ringTapEveryBreaths == 0, profile?.ringGuidesBreath ?? true {
                        services.haptics.playSingle()
                    }
                }
            }
            phaseSecondsLeft = nowInhale ? inS - pos : cycle - pos
            if breathT.truncatingRemainder(dividingBy: 1) == 0 {
                elapsed += 1
                if hrStart == nil, let first = services.heart.samples.first { hrStart = first }
                if isBreathingPhase, let level = services.heart.coherence(breathPeriodS: cycle) { coherence[level, default: 0] += 1 }
            }
        }
        if !finished { finish() }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        services.heart.stop()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(kind == .journey ? "FULL JOURNEY" : kind.title.uppercased()) · \(elapsed < 60 ? "\(elapsed) SEC" : "\(elapsed / 60) MIN")").font(EFont.label).tracking(1.2).foregroundStyle(Color(hex: "#7FB2F0")).padding(.top, 30)
            Text("Nicely done").font(EFont.display(32)).padding(.bottom, 8)
            if !coherence.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Time in coherence").font(EFont.body(15, .bold))
                    GeometryReader { geo in
                        let total = Double(max(1, coherence.values.reduce(0, +)))
                        HStack(spacing: 0) {
                            Color(hex: "#3A4560").frame(width: geo.size.width * Double(coherence[.low] ?? 0) / total)
                            Color(hex: "#7FB2F0").frame(width: geo.size.width * Double(coherence[.medium] ?? 0) / total)
                            EColor.accent.frame(width: geo.size.width * Double(coherence[.high] ?? 0) / total)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 14)
                    HStack {
                        ForEach([CoherenceLevel.low, .medium, .high], id: \.rawValue) { l in
                            VStack(alignment: .leading) {
                                Text(l.name).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                                Text(timeString(Double(coherence[l] ?? 0))).font(EFont.body(17, .bold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(16).eCard()
            }
            HStack(spacing: 10) {
                stat("Heart rate", value: hrStart.flatMap { s in services.heart.current.map { "\(s) → \($0)" } } ?? "—",
                     unit: hrStart == nil ? "no ring data this session" : "bpm, start to end")
                stat("Session", value: timeString(Double(elapsed)), unit: "minutes")
            }
            hrvCard
            Text("How do you feel now?").font(EFont.body(15, .semibold)).padding(.top, 10)
            HStack(spacing: 8) {
                ForEach(["Calmer", "About the same", "Restless"], id: \.self) { t in
                    Button { feelAfter = t } label: {
                        Text(t).font(EFont.body(14, .semibold)).foregroundStyle(feelAfter == t ? EColor.ground : EColor.text)
                            .padding(.horizontal, 16).frame(minHeight: 44).background(feelAfter == t ? EColor.text : EColor.cardRaised, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            let f = profile?.activeFeeling ?? .gratitude
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("End with a \(f.name.lowercased()) cue").font(EFont.body(15, .semibold))
                    Text("Link this calm to your trained rhythm").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
                Spacer()
                Button("Play") { services.haptics.play(f.touch) }
                    .font(EFont.body(14, .bold)).foregroundStyle(EColor.onAccent).padding(.horizontal, 16).frame(height: 40).background(f.color, in: Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 14).eCard(f.ground)
            Spacer()
            Button("Done") { save(); dismiss() }.buttonStyle(PrimaryButtonStyle(color: EColor.text, foreground: EColor.ground))
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
        .emotionScreen()
    }

    /// HRV can't be streamed by these rings; show the ring's own readings and offer a spot measurement.
    private var hrvCard: some View {
        let canMeasure = !services.heart.usingSimulator && services.client.state == .connected
            && services.client.activeCapabilities.contains(.manualHrv)
        let value: String = {
            switch (hrvBefore, hrvAfter) {
            case let (b?, a?): return "\(b) → \(a)"
            case let (nil, a?): return "\(a)"
            case let (b?, nil): return "\(b)"
            default: return "—"
            }
        }()
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HRV").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                Text(value).font(EFont.body(22, .bold))
                Text(hrvAfter != nil ? "ms, before → now" : hrvBefore != nil ? "ms, latest ring reading" : "ms · no recent ring reading")
                    .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            }
            Spacer()
            if canMeasure {
                Button {
                    measuringHRV = true
                    Task {
                        let v = await services.coordinator.measureHRV()
                        if let v { hrvAfter = v }
                        measuringHRV = false
                    }
                } label: {
                    Text(measuringHRV ? "Measuring…" : "Measure now").font(EFont.body(14, .bold))
                        .foregroundStyle(EColor.calmGround).padding(.horizontal, 16).frame(height: 40)
                        .background(Color(hex: "#7FB2F0"), in: Capsule())
                }
                .disabled(measuringHRV)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
    }

    /// Most recent HRV the ring has recorded (PulseLoop's `Measurement` store).
    private func latestHRV(within seconds: TimeInterval) -> Int? {
        let kind = MeasurementKind.hrv.rawValue
        let since = Date().addingTimeInterval(-seconds)
        var d = FetchDescriptor<Measurement>(
            predicate: #Predicate { $0.kindRaw == kind && $0.timestamp >= since },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first.map { Int($0.value.rounded()) }
    }

    private func stat(_ title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            Text(value).font(EFont.body(22, .bold))
            Text(unit).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
    }

    private func save() {
        let r = MeditationRecord(kind: kind.rawValue)
        r.durationS = elapsed
        r.lowS = coherence[.low] ?? 0; r.mediumS = coherence[.medium] ?? 0; r.highS = coherence[.high] ?? 0
        r.hrStart = hrStart; r.hrEnd = services.heart.current
        r.feelAfter = feelAfter
        context.insert(r)
        try? context.save()
    }
}

struct Sparkline: Shape {
    let values: [Double]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1, let lo = values.min(), let hi = values.max() else {
            p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p
        }
        let span = max(4, hi - lo)
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: rect.width * CGFloat(i) / CGFloat(values.count - 1), y: rect.height * (1 - CGFloat((v - lo) / span)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

/// Built-in calm illustrations (Assets.xcassets/Calm, mirrored in Android res/drawable-nodpi).
/// Original images made in code; generator: docs/emotion-app/calm_images.py.
enum CalmImages {
    static let secondsPerImage = 20
    static let all = ["calm_lake_02", "calm_monk_02", "calm_water_01", "calm_circles_01", "calm_mountains_01", "calm_waterfall_01",
                      "calm_monk_01", "calm_stream_01", "calm_lake_01", "calm_circles_02", "calm_monk_03"]

    static func names(for kind: MeditationKind) -> [String] {
        switch kind {
        case .relax: ["calm_lake_02", "calm_monk_02", "calm_water_01", "calm_mountains_01", "calm_stream_01", "calm_lake_01"]
        case .coherence: ["calm_circles_01", "calm_waterfall_01", "calm_monk_01", "calm_circles_02", "calm_lake_01", "calm_monk_03"]
        case .calmBreath: ["calm_monk_03", "calm_water_01", "calm_lake_02"]
        case .journey: all
        }
    }
}

/// Slow, dimmed slideshow behind a meditation session.
struct CalmBackdrop: View {
    let names: [String]
    let index: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !names.isEmpty {
                    Image(names[index % names.count]).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                        .id(index % names.count)
                        .transition(.opacity)
                }
                // Keep text and the breath circle readable.
                LinearGradient(colors: [EColor.calmGround.opacity(0.55), EColor.calmGround.opacity(0.25), EColor.calmGround.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
            }
            .animation(.easeInOut(duration: 2.5), value: index % max(1, names.count))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Heart rate over the last `window` seconds (newest on the right), with each in-breath shaded.
struct HeartRhythmChart: View {
    let points: [(t: Date, bpm: Int)]
    let inhaleStarts: [Date]
    let inhaleSeconds: Double
    let window: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date
                func x(_ t: Date) -> CGFloat { size.width * CGFloat(1 - now.timeIntervalSince(t) / window) }
                // In-breath bands.
                for start in inhaleStarts {
                    let x0 = max(0, x(start)), x1 = min(size.width, x(start.addingTimeInterval(inhaleSeconds)))
                    guard x1 > x0 else { continue }
                    ctx.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: size.height)), with: .color(Color(hex: "#7FB2F0").opacity(0.14)))
                }
                // Baseline grid.
                for f in [0.25, 0.5, 0.75] {
                    var g = Path(); g.move(to: CGPoint(x: 0, y: size.height * f)); g.addLine(to: CGPoint(x: size.width, y: size.height * f))
                    ctx.stroke(g, with: .color(.white.opacity(0.06)), lineWidth: 1)
                }
                guard points.count > 1 else { return }
                let values = points.map { Double($0.bpm) }
                let lo = values.min()!, hi = values.max()!
                let mid = (lo + hi) / 2, span = max(8, hi - lo) * 1.25
                func y(_ v: Double) -> CGFloat { size.height * CGFloat(0.5 - (v - mid) / span) }
                var line = Path()
                for (i, p) in points.enumerated() {
                    let pt = CGPoint(x: x(p.t), y: y(Double(p.bpm)))
                    i == 0 ? line.move(to: pt) : line.addLine(to: pt)
                }
                ctx.stroke(line, with: .color(Color(hex: "#EEF4FF")), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                if let last = points.last {
                    let c = CGPoint(x: x(last.t), y: y(Double(last.bpm)))
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(Color(hex: "#F2B45A")))
                }
            }
        }
    }
}
