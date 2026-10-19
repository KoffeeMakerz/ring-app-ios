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
                                Button("4 in · 6 out (6/min)") { profile.breathInSeconds = 4; profile.breathOutSeconds = 6 }
                                Button("5 in · 5 out (6/min)") { profile.breathInSeconds = 5; profile.breathOutSeconds = 5 }
                                Button("5.5 in · 5.5 out (5.5/min)") { profile.breathInSeconds = 5.5; profile.breathOutSeconds = 5.5 }
                            } label: {
                                Text("\(fmt(profile.breathInSeconds)) in · \(fmt(profile.breathOutSeconds)) out").font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                            }
                        }
                        .frame(minHeight: 56)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Ring guides my breath", subtitle: "A buzz at each inhale, so eyes can close", isOn: $profile.ringGuidesBreath)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Live heart feedback", subtitle: "Optional · uses ring heart rate", isOn: $profile.liveHeartFeedback)
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

/// 4.4 Session player: phases, breath pacer (+ ring buzz on each inhale), live coherence estimate.
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
    @State private var showHeart = true
    @State private var coherence: [CoherenceLevel: Int] = [:]
    @State private var hrStart: Int?
    @State private var finished = false
    @State private var feelAfter: String?

    private var profile: EmotionProfile? { profiles.first }
    private var inS: Double { profile?.breathInSeconds ?? 5 }
    private var outS: Double { profile?.breathOutSeconds ?? 5 }

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
    private var isBreathingPhase: Bool { phaseName.contains("Coherence") }

    var body: some View {
        Group { if finished { summary } else { session } }
            .onAppear { if profile?.liveHeartFeedback ?? true { services.heart.start() } }
            .onDisappear { services.heart.stop(); services.haptics.stop(sendStop: false) }
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
            ZStack {
                Circle().stroke(Color(hex: "#22324D")).frame(width: 240, height: 240)
                Circle().fill(Color(hex: "#1B3355")).frame(width: 190, height: 190)
                    .scaleEffect(isBreathingPhase ? (inhale ? 1.12 : 0.78) : 1)
                    .animation(.easeInOut(duration: inhale ? inS : outS), value: inhale)
                VStack(spacing: 4) {
                    Text(isBreathingPhase ? (inhale ? "Breathe in" : "Breathe out") : (phaseName == "Reflect" ? "Reflect" : "Let go")).font(EFont.display(28))
                    Text(isBreathingPhase ? "\(Int(phaseSecondsLeft.rounded(.up)))" : (phaseName == "Reflect" ? "What do you feel now?" : "Soften from head to toe")).font(EFont.body(15)).foregroundStyle(EColor.textSecondary)
                }
            }
            .frame(height: 300)
            Spacer()
            if showHeart, profile?.liveHeartFeedback ?? true { heartPanel }
            Spacer(minLength: 16)
            HStack(spacing: 28) {
                Button { showHeart.toggle() } label: { Image(systemName: showHeart ? "eye.slash" : "eye").frame(width: 52, height: 52).background(EColor.calmCard, in: Circle()) }
                    .accessibilityLabel(showHeart ? "Hide heart feedback" : "Show heart feedback")
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
        .emotionScreen(EColor.calmGround)
        .task { await runClock() }
    }

    private var heartPanel: some View {
        let level = services.heart.coherence(breathPeriodS: inS + outS)
        let samples = services.heart.samples.suffix(40)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Heart rhythm").font(EFont.body(15, .bold))
                Spacer()
                Text(services.heart.current.map { "Signal good · \($0) bpm" } ?? "Waiting for ring…").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            }
            Sparkline(values: samples.map(Double.init)).stroke(Color(hex: "#7FB2F0"), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                .frame(height: 64)
                .accessibilityLabel("Heart rate trace")
            HStack(spacing: 6) {
                ForEach([CoherenceLevel.low, .medium, .high], id: \.rawValue) { l in
                    Capsule().fill(level == l ? (l == .high ? EColor.accent : l == .medium ? Color(hex: "#7FB2F0") : Color(hex: "#3A4560")) : Color(hex: "#22324D")).frame(height: 8)
                }
            }
            HStack {
                Text("Low"); Spacer()
                Text(level.map { "\($0.name) coherence" } ?? "Measuring…").fontWeight(.bold).foregroundStyle(EColor.text)
                Spacer(); Text("High")
            }
            .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            Text("An estimate from your ring's pulse. Not a medical reading.").font(EFont.body(12)).foregroundStyle(EColor.textMuted)
        }
        .padding(16).eCard(EColor.calmCard, radius: 22)
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
                if inhale, isBreathingPhase, profile?.ringGuidesBreath ?? true { services.haptics.playSingle() }
            }
            phaseSecondsLeft = nowInhale ? inS - pos : cycle - pos
            if breathT.truncatingRemainder(dividingBy: 1) == 0 {
                elapsed += 1
                if hrStart == nil { hrStart = services.heart.current }
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
                stat("Heart rate", value: hrStart.flatMap { s in services.heart.current.map { "\(s) → \($0)" } } ?? "—", unit: "bpm, start to end")
                stat("Session", value: timeString(Double(elapsed)), unit: "minutes")
            }
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
