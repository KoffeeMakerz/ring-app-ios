import SwiftData
import SwiftUI

/// 7.2 Home — experiences first: today's vision to live, the next cue, your other visions, and a
/// smaller way into practising single emotions.
struct HomeView: View {
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \ReminderEvent.scheduledAt) private var events: [ReminderEvent]
    @Query private var profiles: [EmotionProfile]

    /// The vision most recently lived (or made).
    private var today: Experience? {
        experiences.max { ($0.lastPlayedAt ?? $0.createdAt) < ($1.lastPlayedAt ?? $1.createdAt) }
    }
    private var others: [Experience] { experiences.filter { $0.id != today?.id } }
    private var nextEvent: ReminderEvent? { events.first { $0.status == "scheduled" && $0.scheduledAt > Date() } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting).font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                        Text("Live it today").font(EFont.display(26))
                    }
                    Spacer()
                    Button { router.tab = .ring } label: {
                        HStack(spacing: 8) {
                            Circle().fill(services.haptics.isRingConnected ? EColor.success : EColor.warning).frame(width: 8, height: 8)
                            Text(services.haptics.batteryPercent.map { "\($0)%" } ?? (services.haptics.isRingConnected ? "On" : "Off")).font(EFont.body(13, .semibold))
                        }
                        .padding(.horizontal, 12).frame(height: 36).background(EColor.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(services.haptics.isRingConnected ? "Ring connected" : "Ring not connected")
                }
                .padding(.top, 8)

                if let exp = today { todayCard(exp) } else { firstVisionCard }

                Button { router.push(.reminders) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "alarm").foregroundStyle(EColor.accent).frame(width: 40, height: 40).background(EColor.cardRaised, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextEvent.map { e in
                                let time = e.scheduledAt.formatted(date: .omitted, time: .shortened)
                                return Calendar.current.isDateInToday(e.scheduledAt) ? "Next cue around \(time)" : "Next cue tomorrow, \(time)"
                            } ?? "No reminders yet")
                            .font(EFont.body(15, .semibold))
                            Text(cueSubtitle).font(EFont.body(13)).foregroundStyle(EColor.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12).eCard()
                }
                .buttonStyle(.plain)

                if let profile = profiles.first {
                    HomeStatsStrip(profile: profile) { router.tab = .ring }
                }

                if today != nil {
                    HStack {
                        SectionLabel("Your experiences")
                        Spacer()
                        Button("See all") { router.tab = .library }.buttonStyle(TextLinkButtonStyle())
                    }
                    .padding(.top, 2)
                    HStack(spacing: 10) {
                        ForEach(others.prefix(2)) { exp in
                            Button { router.training = TrainingRequest(feeling: exp.feeling, experienceID: exp.id) } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    SlideTile(experience: exp, index: 0, fallback: exp.feeling).frame(height: 64).clipped()
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(exp.title).font(EFont.body(13, .bold)).lineLimit(2).multilineTextAlignment(.leading)
                                        ArcDots(feelings: exp.feelings)
                                    }
                                    .padding(10)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                                .eCard(radius: 18).clipShape(RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Live \(exp.title)")
                        }
                        Button { router.push(.builder(nil)) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                                Text("New vision").font(EFont.body(13, .bold))
                            }
                            .foregroundStyle(EColor.accent)
                            .frame(maxWidth: .infinity, minHeight: 132)
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { router.tab = .train } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Practise an emotion").font(EFont.body(15, .semibold))
                            Text("Strengthen a touch on its own · 5 min").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        ArcDots(feelings: [.joy, .gratitude, .love], size: 10)
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12).eCard()
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    quick("Meditate", "water.waves", Color(hex: "#7FB2F0")) { router.tab = .meditate }
                    quick("Learn", "play.rectangle", Color(hex: "#B892FF")) { router.push(.learn) }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var cueSubtitle: String {
        guard let e = nextEvent else { return "Set reminders to keep your vision alive" }
        if let id = e.experienceID, let exp = experiences.first(where: { $0.id == id }) {
            return "\(exp.title) · " + exp.feelings.map { $0.name.lowercased() }.joined(separator: ", then ")
        }
        return e.feeling.name
    }

    private func todayCard(_ exp: Experience) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                SlideTile(experience: exp, index: 0, fallback: exp.feeling).frame(height: 104).clipped()
                Text("TODAY'S EXPERIENCE").font(EFont.body(11, .bold)).tracking(0.8).foregroundStyle(EColor.accent)
                    .padding(.horizontal, 10).frame(height: 26).background(EColor.ground, in: Capsule()).padding(12)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(exp.title).font(EFont.display(22))
                if let point = exp.visionPoints.first {
                    Text("“\(point).”").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.top, 3).lineLimit(2)
                }
                ArcChips(feelings: exp.feelings).padding(.top, 12)
                HStack(spacing: 10) {
                    Button { router.training = TrainingRequest(feeling: exp.feeling, experienceID: exp.id) } label: {
                        Label("Live it · \(max(1, exp.track.durationS / 60 + 1)) min", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(height: 48))
                    Button { services.haptics.play(exp.touchSequence) } label: {
                        Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 18)).foregroundStyle(EColor.accent)
                            .frame(width: 48, height: 48).background(EColor.ground, in: Circle())
                    }
                    .accessibilityLabel("Feel this vision's ring touches now")
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
        .eCard(radius: 24)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var firstVisionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What would you love to live?").font(EFont.display(22))
            Text("Pick a vision, feel it as if it's already real, and your ring will bring it back through the day.")
                .font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
            ForEach(VisionTemplate.all.prefix(3)) { t in
                VisionTemplateRow(template: t, selected: false) { router.push(.newFromTemplate(t.id)) }
            }
            Button("Write my own") { router.push(.builder(nil)) }.buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
        }
        .padding(18).eCard(radius: 24)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private func quick(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
                Text(title).font(EFont.body(14, .semibold))
                Spacer()
            }
            .padding(14).frame(maxWidth: .infinity).eCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}

/// "Joy → Gratitude" as coloured chips.
struct ArcChips: View {
    let feelings: [Feeling]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(feelings.enumerated()), id: \.element) { i, f in
                if i > 0 { Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(EColor.textMuted) }
                HStack(spacing: 6) { Circle().fill(f.color).frame(width: 8, height: 8); Text(f.name).font(EFont.body(13, .semibold)) }
                    .padding(.horizontal, 10).frame(height: 28).background(f.ground, in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(feelings.map(\.name).joined(separator: ", then "))
    }
}

/// Compact row of feeling dots.
struct ArcDots: View {
    let feelings: [Feeling]
    var size: CGFloat = 8
    var body: some View {
        HStack(spacing: 4) { ForEach(feelings) { Circle().fill($0.color).frame(width: size, height: size) } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(feelings.map(\.name).joined(separator: ", "))
    }
}
