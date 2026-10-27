import SwiftData
import SwiftUI

enum EOnboardingStep: Hashable { case consent, pair, vibeTest, firstVision, builder(String?), firstReminder(UUID?) }

/// 1.1–1.4, then 7.1 pick a first vision → shape it → live it once → 2.4 reminders for it.
struct EmotionOnboardingView: View {
    @State private var path: [EOnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.consent) }
                .navigationDestination(for: EOnboardingStep.self) { step in
                    switch step {
                    case .consent: ConsentView(progress: 1) { path.append(.pair) }
                    case .pair: PairRingScreen(progress: 2) { path.append(.vibeTest) }
                    case .vibeTest: VibeTestView(progress: 3) { path.append(.firstVision) }
                    case .firstVision: FirstVisionView(progress: 4) { path.append(.builder($0)) }
                    case let .builder(templateID): OnboardingBuilderStep(templateID: templateID) { path.append(.firstReminder($0)) }
                    case let .firstReminder(experienceID): FirstReminderView(experienceID: experienceID)
                    }
                }
        }
    }
}

struct EOnboardingHeader: View {
    var progress: Int?
    var total = 4
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .foregroundStyle(EColor.text)
            if let progress { StepProgress(total: total, current: progress) } else { Spacer() }
        }
        .frame(height: 44)
    }
}

// MARK: 1.1 Welcome

struct WelcomeView: View {
    var onStart: () -> Void
    @Environment(\.modelContext) private var context
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KinoraWordmark().padding(.top, 24)
            Spacer()
            KinoraMark().frame(width: 220, height: 220).frame(maxWidth: .infinity)
            Spacer()
            Text("Feel it.\nThen let your ring remind you.")
                .font(EFont.display(36)).lineSpacing(2).padding(.bottom, 14)
            Text("Practise gratitude, love and joy with music, and give each feeling its own touch on your ring.")
                .font(EFont.body(16)).foregroundStyle(EColor.textSecondary).padding(.bottom, 32)
            Button("Get started", action: onStart).buttonStyle(PrimaryButtonStyle())
            Button("I already have an account") {
                let p = context.emotionProfile(); p.onboardingCompleted = true; try? context.save()
            }
            .buttonStyle(TextLinkButtonStyle()).foregroundStyle(EColor.text).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The Kinnora mark: a ring (the one you wear, lit like an eclipse) around a four-point star.
/// Same design as the app icon (docs/brand/kinora-mark.svg).
struct KinoraMark: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ring = side * 0.6
            ZStack {
                // Light catching the lower-right edge of the ring (-10° to 100°).
                Circle()
                    .trim(from: 0, to: 0.305)
                    .stroke(Color(hex: "#FFC9A6").opacity(0.5), style: StrokeStyle(lineWidth: side * 0.035, lineCap: .round))
                    .rotationEffect(.degrees(-10))
                    .frame(width: ring, height: ring).blur(radius: side * 0.025)
                Circle()
                    .stroke(LinearGradient(colors: [Color(hex: "#B8805A"), Color(hex: "#E2B48C"), Color(hex: "#FFE3C8")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: max(1.5, side * 0.011))
                    .frame(width: ring, height: ring)
                Circle().fill(RadialGradient(colors: [Color(hex: "#FFDCBE").opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: side * 0.18))
                    .frame(width: side * 0.4, height: side * 0.4)
                FourPointStar().fill(Color(hex: "#FFECD6")).frame(width: side * 0.24, height: side * 0.24)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }
}

struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY), r = min(rect.width, rect.height) / 2, k = r * 0.13
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

/// "KINNORA" in wide, light capitals.
struct KinoraWordmark: View {
    var size: CGFloat = 18
    var body: some View {
        Text("KINNORA").font(.system(size: size, weight: .light)).tracking(size * 0.45)
            .accessibilityLabel("Kinnora")
    }
}

struct WelcomeRingArt: View {
    var body: some View {
        ZStack {
            Circle().stroke(EColor.line, lineWidth: 1).frame(width: 240, height: 240)
            Circle().stroke(EColor.accent.opacity(0.9), lineWidth: 14).frame(width: 184, height: 184)
            Circle().stroke(EColor.line, lineWidth: 1).frame(width: 120, height: 120)
            ForEach(Array(Feeling.allCases.enumerated()), id: \.offset) { i, f in
                Circle().fill(f.color).frame(width: 12, height: 12)
                    .offset(y: -120).rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .frame(height: 260)
        .accessibilityHidden(true)
    }
}

// MARK: 1.2 Consent

struct ConsentView: View {
    var progress: Int
    var onNext: () -> Void
    @Environment(\.modelContext) private var context
    @State private var reminders = true
    @State private var heart = false
    @State private var photos = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EOnboardingHeader(progress: progress)
            Text("How this works").font(EFont.display(30)).padding(.top, 28).padding(.bottom, 10)
            Text("You practise a feeling with music while your ring gives a rhythm of gentle buzzes. Over time, that rhythm can become a reminder of the feeling. It's a practice, not a promise, and results differ from person to person.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 22)
            VStack(spacing: 0) {
                ToggleRow(title: "Ring reminders", subtitle: "Buzz your ring at times you choose", isOn: $reminders)
                Divider().overlay(EColor.line)
                ToggleRow(title: "Heart rate & HRV", subtitle: "Optional. Used for meditation feedback only", isOn: $heart)
                Divider().overlay(EColor.line)
                ToggleRow(title: "Your photos", subtitle: "Kept on this phone, never uploaded", isOn: $photos)
            }
            .padding(.horizontal, 18).padding(.vertical, 6).eCard()
            InfoNote(icon: "info.circle", text: "A wellness app, not a medical device. You can mute your ring instantly, export or delete your data any time.")
                .padding(.top, 18)
            Spacer()
            Button("I understand, continue") {
                let p = context.emotionProfile()
                p.consentReminders = reminders; p.consentHeartData = heart; p.consentPhotos = photos
                p.liveHeartFeedback = heart
                try? context.save()
                if reminders { ReminderScheduler.requestPermission() }
                onNext()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(EFont.body(15, .semibold))
                if let subtitle { Text(subtitle).font(EFont.body(13)).foregroundStyle(EColor.textSecondary) }
            }
        }
        .tint(EColor.accent)
        .frame(minHeight: 60)
    }
}

struct InfoNote: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(EColor.textSecondary)
            Text(text).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#17131F"), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(EColor.line))
    }
}

// MARK: 1.3 / 6.1 Pair ring

struct PairRingScreen: View {
    var progress: Int? = nil
    var onDone: (() -> Void)?
    @Environment(EmotionServices.self) private var services
    @Environment(RingBLEClient.self) private var ble
    @State private var showRealPairing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if progress != nil { EOnboardingHeader(progress: progress) }
            Text(progress != nil ? "Connect your devices" : "Pair your ring").font(EFont.display(30)).padding(.top, 24).padding(.bottom, 10)
            Text(progress != nil
                 ? "Kinnora plays each feeling as a touch on a smart ring, an Apple Watch, or both. The ring comes first when both are on. You can change this any time under Devices."
                 : "Put the ring on and keep it close to your phone. It should have some charge.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary)
            ZStack {
                Circle().stroke(EColor.accent.opacity(0.2)).frame(width: 190)
                Circle().stroke(EColor.accent.opacity(0.4)).frame(width: 140)
                Circle().stroke(EColor.accent, lineWidth: 10).frame(width: 88)
            }
            .scaleEffect(progress != nil ? 0.55 : 1)
            .frame(maxWidth: .infinity, minHeight: progress != nil ? 120 : 220).accessibilityHidden(true)

            #if DEBUG
            SectionLabel("Developer").padding(.bottom, 10)
            Button {
                services.simulator.isEnabled = true
                services.simulator.setConnected(true)
                onDone?()
            } label: {
                HStack(spacing: 14) {
                    Circle().strokeBorder(EColor.debug, lineWidth: 6).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulated ring").font(EFont.body(15, .bold))
                        Text("No Bluetooth needed · profile: \(services.simulator.profile.name)").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    }
                    Spacer()
                    Text("Connect").font(EFont.body(14, .bold)).foregroundStyle(EColor.debug)
                }
                .padding(.horizontal, 16).frame(minHeight: 76)
                .background(EColor.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(EColor.debug, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
            #endif

            SectionLabel("Smart ring").padding(.bottom, 10)
            Button { services.simulator.isEnabled = false; services.haptics.useRing = true; showRealPairing = true } label: {
                HStack(spacing: 14) {
                    Circle().strokeBorder(EColor.text, lineWidth: 5).frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ble.state == .connected ? services.haptics.ringName : "Find my ring").font(EFont.body(15, .semibold))
                        Text(ble.state == .connected ? "\(services.haptics.ringDeviceName.map { "\($0) · " } ?? "")Connected\(ble.batteryPercent.map { " · \($0)%" } ?? "") · tap to change" : "Scan for nearby rings").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                }
                .padding(.horizontal, 16).frame(minHeight: 68).eCard(radius: 18)
            }
            .buttonStyle(.plain)
            .opacity(services.haptics.useRing ? 1 : 0.5)
            if progress != nil {
                Button(services.haptics.useRing ? "I don't have a ring" : "I have a ring after all") {
                    services.haptics.useRing.toggle()
                }
                .buttonStyle(TextLinkButtonStyle())
                .padding(.top, 6)

                SectionLabel("Apple Watch").padding(.top, 14).padding(.bottom, 10)
                @Bindable var watch = services.watch
                Toggle(isOn: $watch.useWatch) {
                    HStack(spacing: 14) {
                        Image(systemName: "applewatch").font(.system(size: 20)).frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use my Apple Watch").font(EFont.body(15, .semibold))
                            Text(watch.statusText).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                    }
                }
                .tint(EColor.accent)
                .padding(.horizontal, 16).frame(minHeight: 68).eCard(radius: 18)
            }
            Spacer()
            if let onDone {
                Button(services.haptics.canDeliverTouch ? "Continue" : (progress != nil && !services.haptics.useRing ? "Continue" : "Skip for now"), action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(progress != nil ? .hidden : .automatic, for: .navigationBar)
        .sheet(isPresented: $showRealPairing) {
            PairingView(onConnected: { showRealPairing = false }, onSkip: { showRealPairing = false })
        }
    }
}

// MARK: 1.4 Vibration test

struct VibeTestView: View {
    var progress: Int? = nil
    var onNext: (() -> Void)?
    @Environment(EmotionServices.self) private var services
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var gapIndex = 1
    @State private var comfort: String? = nil
    private let gaps = [300, 600, 900, 1200]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if progress != nil { EOnboardingHeader(progress: progress) }
            Text("Let's feel your ring").font(EFont.display(30)).padding(.top, 24).padding(.bottom, 10)
            Text("Three short checks so we know how your ring buzzes. Rest your hand somewhere still.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 22)
            VStack(spacing: 10) {
                checkCard(index: 0, title: "One buzz", subtitle: step > 0 ? "Felt" : "Did you feel a buzz?") {
                    HStack(spacing: 8) {
                        answer("Felt it", primary: true) { step = 1; playPair() }
                        answer("Buzz again") { services.haptics.playSingle() }
                    }
                }
                checkCard(index: 1, title: "Two buzzes, close together", subtitle: step > 1 ? "Closest you can feel: \(gaps[gapIndex]) ms" : "Did you feel two separate buzzes?") {
                    HStack(spacing: 8) {
                        answer("Two", primary: true) {
                            if gapIndex > 0 { gapIndex -= 1; playPair() } else { step = 2 }
                        }
                        answer("One long") {
                            if gapIndex < gaps.count - 1 { gapIndex += 1; playPair() } else { step = 2 }
                        }
                        answer("That's fine") { step = 2 }
                    }
                }
                checkCard(index: 2, title: "Comfort", subtitle: "Too strong, just right, or too weak?") {
                    HStack(spacing: 8) {
                        ForEach([("strong", "Too strong"), ("right", "Just right"), ("weak", "Too weak")], id: \.0) { key, label in
                            answer(label, primary: comfort == key) { comfort = key; step = 3 }
                        }
                    }
                }
            }
            Spacer()
            Text("We'll use the closest spacing you can feel to build every pattern.")
                .font(EFont.body(13)).foregroundStyle(EColor.textMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.bottom, 14)
            if let onNext {
                Button("Continue") { save(); onNext() }
                    .buttonStyle(PrimaryButtonStyle(color: step >= 3 ? EColor.accent : EColor.cardRaised, foreground: step >= 3 ? EColor.onAccent : EColor.textSecondary))
            } else {
                Button("Save") { save() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(progress != nil ? .hidden : .automatic, for: .navigationBar)
        .navigationTitle(progress == nil ? "Vibration check" : "")
        .task { if step == 0 { try? await Task.sleep(for: .milliseconds(600)); services.haptics.playSingle() } }
    }

    private func playPair() {
        services.haptics.play(TouchPattern(id: "test.pair", name: "Two buzzes", durationsMs: [200, gaps[gapIndex], 200]))
    }

    private func save() {
        let p = context.emotionProfile()
        p.minFeltGapMs = gaps[gapIndex]
        if let comfort { p.buzzComfort = comfort }
        try? context.save()
    }

    @ViewBuilder
    private func checkCard<Content: View>(index: Int, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        let done = step > index, active = step == index
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    if done { Circle().fill(EColor.success); Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(EColor.ground) }
                    else { Circle().strokeBorder(active ? EColor.accent : EColor.textMuted, lineWidth: 2); Text("\(index + 1)").font(EFont.body(14, .bold)).foregroundStyle(active ? EColor.accent : EColor.textSecondary) }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(EFont.body(15, .semibold))
                    Text(subtitle).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
            }
            if active { content() }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .eCard(radius: 18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(active ? EColor.accent : .clear, lineWidth: 1.5))
        .opacity(step < index ? 0.6 : 1)
    }

    private func answer(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(EFont.body(14, primary ? .bold : .semibold))
                .foregroundStyle(primary ? EColor.onAccent : EColor.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(primary ? EColor.accent : EColor.cardRaised, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: 1.5 Choose first feeling

struct ChooseFeelingView: View {
    var progress: Int
    var onPick: (Feeling) -> Void
    @Environment(EmotionServices.self) private var services
    @Environment(\.modelContext) private var context
    @State private var picked: Feeling = .gratitude

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EOnboardingHeader(progress: progress)
            Text("Start with one feeling").font(EFont.display(30)).padding(.top, 24).padding(.bottom, 10)
            Text("Each feeling has its own rhythm on your ring. Learn one well before adding the next.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 22)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Feeling.allCases) { feeling in
                    Button {
                        picked = feeling
                        services.haptics.play(feeling.touch)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Circle().fill(feeling.color).frame(width: 14, height: 14)
                            Text(feeling.name).font(EFont.display(19))
                            Text(feeling.rhythmDescription).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                            Spacer(minLength: 0)
                            TouchGlyph(pattern: feeling.touch, color: feeling.color, scale: 0.02, height: 8)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
                        .eCard()
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(picked == feeling ? feeling.color : EColor.line, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked == feeling ? .isSelected : [])
                }
            }
            Spacer()
            Button("Start with \(picked.name)") {
                let p = context.emotionProfile()
                p.firstFeelingRaw = picked.rawValue
                p.activeFeeling = picked
                try? context.save()
                onPick(picked)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}


// MARK: 7.1 Pick your first vision

struct FirstVisionView: View {
    var progress: Int
    /// Template id, or nil for "Write my own".
    var onPick: (String?) -> Void
    @Environment(\.modelContext) private var context
    @State private var picked: String? = VisionTemplate.all.first?.id

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EOnboardingHeader(progress: progress)
            Text("What would you love to live?").font(EFont.display(30)).padding(.top, 20).padding(.bottom, 10)
            Text("Pick a vision to start. You'll make it yours, then feel it as if it's already real, with your ring marking each feeling.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 18)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(VisionTemplate.all) { t in
                        VisionTemplateRow(template: t, selected: picked == t.id) { picked = t.id }
                    }
                    Button { picked = nil } label: {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12).fill(EColor.cardRaised).frame(width: 40, height: 40)
                                .overlay(Image(systemName: "pencil").foregroundStyle(EColor.textSecondary))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Write my own").font(EFont.body(15, .bold))
                                Text("You choose the feelings").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).frame(minHeight: 64)
                        .background(EColor.cardRaised, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(picked == nil ? EColor.accent : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(picked == nil ? "Write my vision" : "Shape this vision") { onPick(picked) }
                .buttonStyle(PrimaryButtonStyle()).padding(.top, 12)
            Button("Skip for now") {
                let p = context.emotionProfile()
                p.onboardingCompleted = true
                try? context.save()
            }
            .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The builder inside onboarding: save → live it once → reminders.
struct OnboardingBuilderStep: View {
    let templateID: String?
    var onDone: (UUID?) -> Void
    @Environment(EmotionRouter.self) private var router
    @State private var session: TrainingRequest?

    var body: some View {
        ExperienceBuilderView(experienceID: nil, templateID: templateID) { exp, startNow in
            if startNow { session = TrainingRequest(feeling: exp.feeling, experienceID: exp.id) }
            else { onDone(exp.id) }
        }
        .fullScreenCover(item: $session) { request in
            TrainingSessionView(request: request) { _ in
                session = nil
                onDone(request.experienceID)
            }
            .simRingOverlay()
            .environment(router)
        }
    }
}
