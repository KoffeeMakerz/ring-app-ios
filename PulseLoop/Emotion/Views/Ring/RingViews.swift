import SwiftData
import SwiftUI

/// 5.1 Ring & settings.
struct RingSettingsView: View {
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Query private var profiles: [EmotionProfile]
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ring").font(EFont.display(28)).padding(.top, 8)
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        Circle().strokeBorder(services.haptics.usesSimulator ? EColor.debug : EColor.text, lineWidth: 7).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(services.haptics.ringName).font(EFont.body(16, .bold))
                            if let device = services.haptics.ringDeviceName {
                                Text(device).font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                            }
                            HStack(spacing: 6) {
                                Circle().fill(services.haptics.isRingConnected ? EColor.success : EColor.warning).frame(width: 8, height: 8)
                                Text(services.haptics.isRingConnected ? "Connected\(services.haptics.batteryPercent.map { " · \($0)%" } ?? "")" : "Not connected")
                                    .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Button("Test buzz") { services.haptics.playSingle() }.buttonStyle(PrimaryButtonStyle(height: 44))
                        NavigationLink { VibeTestView() } label: { Text("Vibration check") }.buttonStyle(SecondaryButtonStyle(height: 44))
                    }
                    Button { router.push(.pairRing) } label: {
                        Text(services.haptics.isRingConnected ? "Change ring" : "Pair a ring").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TextLinkButtonStyle())
                }
                .padding(16).eCard(radius: 22)

                SectionLabel("Watch").padding(.top, 6)
                WatchCard()

                if let p = profiles.first {
                    @Bindable var profile = p
                    RingStatsSection(profile: p).padding(.top, 6)
                    SectionLabel("Optional stats").padding(.top, 6)
                    VStack(spacing: 0) {
                        ToggleRow(title: "Heart rate & HRV", isOn: $profile.statsHeart)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Sleep", isOn: $profile.statsSleep)
                        Divider().overlay(EColor.line)
                        ToggleRow(title: "Steps & activity", isOn: $profile.statsActivity)
                    }
                    .padding(.horizontal, 16).eCard(radius: 18)
                }

                SectionLabel("More").padding(.top, 6)
                VStack(spacing: 0) {
                    link("Calm cue when tense", badge: "BETA") { router.push(.stressCue) }
                    Divider().overlay(EColor.line)
                    link("Reminders & quiet hours") { router.push(.reminders) }
                    Divider().overlay(EColor.line)
                    link("Guides & help") { router.push(.learn) }
                    Divider().overlay(EColor.line)
                    link("Privacy, export & delete") { confirmReset = true }
                }
                .padding(.horizontal, 16).eCard(radius: 18)

                #if DEBUG
                SectionLabel("Developer").padding(.top, 6)
                VStack(spacing: 0) {
                    ToggleRow(title: "Use simulated ring", subtitle: "Test everything without a ring", isOn: Binding(get: { services.simulator.isEnabled }, set: { services.simulator.isEnabled = $0 }))
                    Divider().overlay(EColor.line)
                    link("Ring simulator panel") { router.push(.simPanel) }
                    Divider().overlay(EColor.line)
                    link("Reminder delivery test (real ring)") { router.push(.deliveryTest) }
                    Divider().overlay(EColor.line)
                    link("Switch to original health screens (button top right brings you back)") {
                        UserDefaults.standard.set(true, forKey: EmotionServices.legacyUIKey)
                    }
                    Divider().overlay(EColor.line)
                    link("Restart onboarding") {
                        context.emotionProfile().onboardingCompleted = false
                        try? context.save()
                    }
                }
                .padding(.horizontal, 16).eCard(radius: 18)
                #endif
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Delete all emotion app data on this phone?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete experiences, training and reminders", role: .destructive) {
                try? context.delete(model: Experience.self)
                try? context.delete(model: TrainingRecord.self)
                try? context.delete(model: ReminderRule.self)
                try? context.delete(model: ReminderEvent.self)
                try? context.delete(model: MeditationRecord.self)
                try? context.delete(model: CustomTouch.self)
                try? context.save()
                ReminderScheduler.rebuild(context: context)
            }
        }
    }

    private func link(_ title: String, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(EFont.body(15, .semibold))
                if let badge { Text(badge).font(EFont.body(11, .bold)).foregroundStyle(Color(hex: "#B892FF")) }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 5.2 Calm cue when tense (beta, off by default).
struct StressCueView: View {
    @Environment(\.modelContext) private var context
    @Environment(EmotionRouter.self) private var router
    @Environment(EmotionServices.self) private var services
    @Query private var profiles: [EmotionProfile]
    @State private var measuringHR = false
    @State private var refresh = 0

    /// What the ring has actually sent, so missing heart-rate history is visible.
    private var ringDataCard: some View {
        let rows = services.calm?.latestReadings() ?? []
        let noHR = rows.first?.at.map { Date().timeIntervalSince($0) > 6 * 3600 } ?? true
        let canMeasure = services.client.state == .connected && services.client.activeCapabilities.contains(.manualHeartRate)
        return VStack(alignment: .leading, spacing: 8) {
            Text("What your ring is sending").font(EFont.body(15, .bold))
            ForEach(rows, id: \.name) { row in
                HStack {
                    Text(row.name).font(EFont.body(14))
                    Spacer()
                    Text(row.value).font(EFont.body(14, .semibold))
                    if let at = row.at {
                        Text("· \(at.formatted(.relative(presentation: .numeric)))").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                    }
                }
            }
            if noHR {
                Text("No recent heart-rate history from your ring. The calm cue still uses HRV and stress, and takes a quick heart-rate reading itself when you're still and the ring is connected.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            if canMeasure {
                Button(measuringHR ? "Measuring… keep your hand still" : "Measure heart rate now") {
                    measuringHR = true
                    Task {
                        _ = await services.coordinator.measureHR()
                        measuringHR = false
                        refresh += 1
                    }
                }
                .font(EFont.body(14, .semibold)).foregroundStyle(EColor.accent).disabled(measuringHR)
            }
        }
        .id(refresh)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
    }

    var body: some View {
        let profile = profiles.first
        let enabled = profile?.calmCueEnabled ?? false
        let baseline = services.calm?.baseline() ?? CalmCueMonitor.Baseline()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("BETA · OFF BY DEFAULT").font(EFont.label).tracking(1.2).foregroundStyle(Color(hex: "#B892FF"))
                Text("A calm cue when you seem tense").font(EFont.display(30))
                Text("When you've been sitting still and your ring's readings look tense compared with your normal, your ring plays a slow-down touch and you get a 1½-minute breath: in for 4, out for 7. It's a guess, so it will sometimes be wrong.")
                    .font(EFont.body(15)).foregroundStyle(EColor.textSecondary)

                if enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Right now").font(EFont.body(15, .bold))
                            Spacer()
                            Button("Check now") { services.calm?.evaluate(trigger: "manual check", force: true) }
                                .font(EFont.body(14, .semibold)).foregroundStyle(EColor.accent)
                        }
                        Text(services.calm?.lastAssessment ?? "Not checked yet").font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Only when all of these are true").font(EFont.body(15, .bold))
                    ForEach(["Still for \(Int(CalmCueMonitor.stillMinutes)) minutes, so a walk or workout never counts",
                             "A fresh reading from the ring in the last \(Int(CalmCueMonitor.readingWindowMinutes)) minutes",
                             "Stress score, heart rate or HRV clearly off your normal",
                             "At most once every \(Int(CalmCueMonitor.cooldownHours)) hours, never in quiet hours"], id: \.self) { t in
                        Label(t, systemImage: "checkmark").font(EFont.body(14)).foregroundStyle(EColor.text)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()

                ringDataCard

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Learning your normal").font(EFont.body(15, .bold))
                        Spacer()
                        Text("\(min(baseline.days, 7)) of 7 days").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    }
                    ThinProgress(value: Double(min(baseline.days, 7)) / 7, color: Color(hex: "#7FB2F0"))
                    Text(baseline.ready
                         ? [baseline.restingHR.map { "Resting heart rate about \(Int($0)) bpm" }, baseline.hrvMedian.map { "usual HRV \(Int($0)) ms" }].compactMap { $0 }.joined(separator: " · ") + ". Works from now; gets better over 7 days."
                         : "Needs \(CalmCueMonitor.minBaselineDays) days of readings (heart rate, HRV or stress) from your ring before it can start.")
                        .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
                .padding(16).eCard()

                if let p = profile {
                    @Bindable var profile = p
                    VStack(alignment: .leading, spacing: 10) {
                        Text("When to cue").font(EFont.body(15, .bold))
                        Picker("When to cue", selection: $profile.calmCueSensitivity) {
                            Text("Raised or high").tag("elevated")
                            Text("High only").tag("high")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: profile.calmCueSensitivity) { try? context.save() }
                    }
                    .padding(16).eCard()
                }

                HStack(spacing: 14) {
                    TouchGlyph(pattern: .calmCue, color: Feeling.calm.color, scale: 0.012)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slow down").font(EFont.body(15, .semibold))
                        Text("Five hums, each gap longer").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    }
                    Spacer()
                    Button("Feel it") { services.haptics.play(.calmCue) }
                        .font(EFont.body(14, .bold)).foregroundStyle(EColor.calmGround)
                        .padding(.horizontal, 16).frame(height: 40).background(Feeling.calm.color, in: Capsule())
                }
                .padding(16).eCard()

                Button { router.meditation = .calmBreath } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Try the calm breath").font(EFont.body(15, .semibold))
                            Text("1½ min · in for 4, out for 7 · a ring tap every few breaths").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(16).eCard()
                }
                .buttonStyle(.plain)

                if let log = services.calm?.log, !log.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Recent checks").font(EFont.body(15, .bold))
                            Spacer()
                            Button("Clear") { services.calm?.clearLog() }.font(EFont.body(13, .semibold)).foregroundStyle(EColor.accent)
                        }
                        ForEach(Array(log.prefix(10).enumerated()), id: \.offset) { _, line in
                            Text(line).font(EFont.body(12)).foregroundStyle(EColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
                }

                #if DEBUG
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEVELOPER").font(EFont.label).tracking(1.2).foregroundStyle(EColor.debug)
                    Button("Test: calm cue + notification now") { services.calm?.playTest(withNotification: true) }
                        .font(EFont.body(14, .semibold)).foregroundStyle(EColor.debug)
                    Text("Skips every check. Lock the phone right after tapping to see the notification.")
                        .font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
                #endif

                Text("Not a medical or diagnostic feature. On iPhone it checks when the app gets new ring data, so a cue can come a little after the moment.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 10)
                Button(enabled ? "Turn off calm cue" : "Turn on calm cue") {
                    context.emotionProfile().calmCueEnabled.toggle()
                    try? context.save()
                    if context.emotionProfile().calmCueEnabled {
                        ReminderScheduler.requestPermission()
                        services.calm?.evaluate(trigger: "turned on", force: true)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 5.3 Learn & guides.
struct LearnView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Short videos to get the most from your ring.").font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 8)
                ForEach(["Getting started", "Meditation", "Safety & help"], id: \.self) { group in
                    SectionLabel(group).padding(.top, 6)
                    ForEach(GuideVideo.all.filter { $0.group == group }) { v in
                        HStack(spacing: 14) {
                            Image(systemName: "play.fill").frame(width: 84, height: 56).background(EColor.cardRaised, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.title).font(EFont.body(15, .semibold))
                                Text(v.meta).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(8).eCard(radius: 16)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Learn")
    }
}


/// The paired watch (Apple Watch today; Garmin and Amazfit later): status, where touches play, and a test.
struct WatchCard: View {
    @Environment(EmotionServices.self) private var services

    var body: some View {
        @Bindable var watch = services.watch
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "applewatch")
                    .font(.system(size: 22))
                    .frame(width: 48, height: 48)
                    .background(EColor.cardRaised, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch").font(EFont.body(16, .bold))
                    // Only Apple Watch can link to an iPhone app today; Garmin and Amazfit are planned.
                    Text("Apple Watch").font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                    HStack(spacing: 6) {
                        Circle().fill(watch.isReachable ? EColor.success : EColor.warning).frame(width: 8, height: 8)
                        Text(watch.statusText).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Touches play on").font(EFont.body(13, .semibold)).foregroundStyle(EColor.textSecondary)
                Picker("Touches play on", selection: $watch.target) {
                    ForEach(TouchTarget.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Text("The watch plays touches while Kinnora is open on it. Start a session on the watch to keep it listening with your wrist down. Reminders also show on the watch as notifications. With \"Watch\" chosen and no watch around, touches go to the ring.")
                .font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Test watch") { watch.play(Feeling.gratitude.touch, force: true) }
                .buttonStyle(SecondaryButtonStyle(height: 44))
                .disabled(!watch.isReachable)
            if let error = watch.lastError {
                Text("Couldn't reach the watch: \(error)").font(EFont.body(12)).foregroundStyle(EColor.warning)
            }
        }
        .padding(16).eCard(radius: 22)
    }
}
