import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @Query private var profiles: [EmotionProfile]
    @Query(sort: \TrainingRecord.completedAt, order: .reverse) private var records: [TrainingRecord]
    @Query(sort: \ReminderEvent.scheduledAt) private var events: [ReminderEvent]

    private var feeling: Feeling { profiles.first?.activeFeeling ?? .gratitude }
    private var nextEvent: ReminderEvent? { events.first { $0.status == "scheduled" && $0.scheduledAt > Date() } }
    private var todayCount: (done: Int, total: Int) {
        let today = events.filter { Calendar.current.isDateInToday($0.scheduledAt) }
        return (today.filter { $0.scheduledAt <= Date() }.count, today.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting).font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                        Text("Today: \(feeling.name.lowercased())").font(EFont.display(26))
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

                VStack(alignment: .leading, spacing: 0) {
                    TouchGlyph(pattern: feeling.touch, color: feeling.color, scale: 0.025, height: 10)
                    Text("“\(feeling.intention)”").font(EFont.display(21, .medium)).padding(.vertical, 16)
                    HStack(spacing: 10) {
                        Button("Practise · 5 min") { router.training = TrainingRequest(feeling: feeling, experienceID: nil) }
                            .buttonStyle(PrimaryButtonStyle(color: feeling.color, height: 48))
                        Button { services.haptics.play(feeling.touch) } label: {
                            Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 18)).foregroundStyle(feeling.color)
                                .frame(width: 48, height: 48).background(EColor.ground, in: Circle())
                        }
                        .accessibilityLabel("Feel the \(feeling.name.lowercased()) rhythm now")
                    }
                }
                .padding(20).eCard(feeling.ground, radius: 24)

                Button { router.push(.reminders) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "alarm").foregroundStyle(feeling.color).frame(width: 44, height: 44).background(EColor.cardRaised, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextEvent.map { e in
                                let time = e.scheduledAt.formatted(date: .omitted, time: .shortened)
                                return Calendar.current.isDateInToday(e.scheduledAt) ? "Next ring cue around \(time)" : "Next ring cue tomorrow, \(time)"
                            } ?? "No reminders yet")
                                .font(EFont.body(15, .semibold))
                            Text(nextEvent == nil ? "Set reminders to keep the feeling alive"
                                 : todayCount.total == 0 ? "\(feeling.name) · none left today"
                                 : "\(feeling.name) · \(todayCount.done) of \(todayCount.total) today")
                                .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14).eCard()
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    quick("Meditate", "water.waves", Color(hex: "#7FB2F0")) { router.tab = .meditate }
                    quick("Create", "plus", Color(hex: "#F27A9B")) { router.push(.builder(nil)) }
                    quick("Learn", "play.rectangle", Color(hex: "#B892FF")) { router.push(.learn) }
                }

                SectionLabel("Your feelings").padding(.top, 4)
                ForEach(Feeling.unlockOrder.prefix(3)) { f in
                    let n = FeelingProgress.sessions(f, records)
                    let unlocked = FeelingProgress.isUnlocked(f, records: records, first: profiles.first?.firstFeeling ?? .gratitude)
                    Button { if unlocked { router.push(.trainIntro(f)) } } label: {
                        HStack(spacing: 12) {
                            Circle().fill(f.color).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name).font(EFont.body(15, .semibold))
                                if !unlocked { Text(FeelingProgress.lockReason(f)).font(EFont.body(12)).foregroundStyle(EColor.textSecondary) }
                            }
                            Spacer()
                            if unlocked {
                                ThinProgress(value: Double(n) / 7, color: f.color).frame(width: 90)
                                Text("\(min(n, 7))/7").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).frame(width: 28, alignment: .trailing)
                            } else {
                                Image(systemName: "lock").foregroundStyle(EColor.textMuted)
                            }
                        }
                        .padding(.horizontal, 16).frame(minHeight: 52).eCard(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private func quick(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
                Text(title).font(EFont.body(14, .semibold))
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).eCard(radius: 18)
        }
        .buttonStyle(.plain)
    }
}
