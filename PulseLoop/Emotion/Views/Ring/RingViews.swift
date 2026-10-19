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
                            HStack(spacing: 6) {
                                Circle().fill(services.haptics.isRingConnected ? EColor.success : EColor.warning).frame(width: 8, height: 8)
                                Text(services.haptics.isRingConnected ? "Connected · \(services.haptics.batteryPercent.map { "\($0)%" } ?? "—")" : "Not connected")
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

                if let p = profiles.first {
                    @Bindable var profile = p
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
                    link("Switch to original PulseLoop UI") {
                        UserDefaults.standard.set(true, forKey: EmotionServices.legacyUIKey)
                    }
                    Divider().overlay(EColor.line)
                    link("Restart onboarding") {
                        context.emotionProfile().onboardingCompleted = false
                        try? context.save()
                    }
                }
                .padding(.horizontal, 16).eCard(radius: 18)
                Text("Switching to the original UI takes effect after relaunching the app.").font(EFont.body(12)).foregroundStyle(EColor.textMuted)
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
    @Query private var profiles: [EmotionProfile]
    @Query private var records: [TrainingRecord]

    var body: some View {
        let enabled = profiles.first?.calmCueEnabled ?? false
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("BETA · OFF BY DEFAULT").font(EFont.label).tracking(1.2).foregroundStyle(Color(hex: "#B892FF"))
                Text("A calm cue when you seem tense").font(EFont.display(30))
                Text("When you're sitting still and your heart signals look tense compared with your normal, your ring plays the calm rhythm. It's a guess, so it will sometimes be wrong.")
                    .font(EFont.body(15)).foregroundStyle(EColor.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Only when all of these are true").font(EFont.body(15, .bold))
                    ForEach(["Still for at least 10 minutes", "No workout in the last 45 minutes", "A clear reading from the ring", "At most once every 2 hours"], id: \.self) { t in
                        Label(t, systemImage: "checkmark").font(EFont.body(14)).foregroundStyle(EColor.text)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard()
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("Learning your normal").font(EFont.body(15, .bold)); Spacer(); Text("0 of 7 days").font(EFont.body(13)).foregroundStyle(EColor.textSecondary) }
                    ThinProgress(value: 0, color: Color(hex: "#7FB2F0"))
                    HStack {
                        TouchGlyph(pattern: Feeling.calm.touch, color: Feeling.calm.color, scale: 0.012)
                        Text("Uses your **Calm** rhythm").font(EFont.body(14))
                        Spacer()
                        if FeelingProgress.sessions(.calm, records) < 3 {
                            Button("Train it first") { router.push(.trainIntro(.calm)) }.buttonStyle(TextLinkButtonStyle())
                        }
                    }
                }
                .padding(16).eCard()
                Text("Not a medical or diagnostic feature. Detection itself ships in a later version; turning this on now only records your choice.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 10)
                Button(enabled ? "Turn off calm cue" : "Turn on calm cue") {
                    context.emotionProfile().calmCueEnabled.toggle(); try? context.save()
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
