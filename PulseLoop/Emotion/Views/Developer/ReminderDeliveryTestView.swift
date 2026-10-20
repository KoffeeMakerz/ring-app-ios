#if DEBUG
import SwiftData
import SwiftUI
import UserNotifications

/// Developer-only (debug builds): checks how reminder cues actually reach a real ring on this
/// iPhone — on time, late, or missed — with the phone locked. Not shown in release builds.
struct ReminderDeliveryTestView: View {
    @Environment(\.modelContext) private var context
    @Environment(EmotionServices.self) private var services
    @Query(sort: \ReminderEvent.scheduledAt, order: .reverse) private var events: [ReminderEvent]
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]

    private var recent: [ReminderEvent] { Array(events.filter { $0.scheduledAt <= Date().addingTimeInterval(3600) }.prefix(40)) }
    private var tests: [ReminderEvent] { events.filter(\.isTest) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                SectionLabel("Test")
                VStack(spacing: 8) {
                    Button("Schedule test cues in 2, 5 and 10 min") { scheduleTests() }
                        .buttonStyle(PrimaryButtonStyle(height: 50))
                    HStack(spacing: 8) {
                        Button("Check now") { services.dispatcher?.check(.manual) }
                            .buttonStyle(SecondaryButtonStyle(height: 46))
                        Button("Clear test cues") { clearTests() }
                            .buttonStyle(SecondaryButtonStyle(height: 46))
                    }
                }
                procedure
                SectionLabel("Delivery log").padding(.top, 4)
                VStack(spacing: 0) {
                    if recent.isEmpty {
                        Text("No cues yet").font(EFont.body(14)).foregroundStyle(EColor.textSecondary).frame(maxWidth: .infinity, minHeight: 52)
                    }
                    ForEach(recent) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(e.scheduledAt.formatted(date: .abbreviated, time: .shortened)).font(EFont.body(13, .semibold))
                                if e.isTest { Text("TEST").font(EFont.body(10, .bold)).foregroundStyle(EColor.debug) }
                                Spacer()
                                Text(cueStatusText(e)).font(EFont.body(13, .bold)).foregroundStyle(color(e))
                            }
                            if let via = e.deliveredVia, e.status == "delivered" {
                                Text("via \(via) · sent \(e.deliveredAt?.formatted(date: .omitted, time: .standard) ?? "")").font(EFont.mono(11)).foregroundStyle(EColor.textSecondary)
                            }
                        }
                        .padding(.vertical, 10)
                        Divider().overlay(EColor.line)
                    }
                }
                .padding(.horizontal, 16).eCard(radius: 18)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Reminder delivery test").navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Ring", services.haptics.usesSimulator ? "Simulated ring — turn it off to test a real ring" : (services.haptics.isRingConnected ? "\(services.haptics.ringName) connected" : "Not connected"))
            row("Last check", services.dispatcher?.lastCheckAt.map { "\($0.formatted(date: .omitted, time: .standard)) · \(services.dispatcher?.lastTrigger?.rawValue ?? "")" } ?? "—")
            row("Test cues", "\(tests.filter { $0.status == "delivered" }.count) delivered · \(tests.filter { $0.status == "missed" }.count) missed · \(tests.filter { $0.status == "scheduled" }.count) waiting")
            row("Late limit", "\(Int(CueDispatcher.graceSeconds / 60)) min, then skipped")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard(radius: 18)
    }

    private var procedure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-device procedure").font(EFont.body(14, .bold))
            ForEach(Array([
                "Turn off the simulated ring and connect your real ring.",
                "Tap \"Schedule test cues\", then lock the phone and leave it alone (another room is fine; keep the ring on).",
                "Note when the ring buzzes for each cue (2, 5, 10 min).",
                "After 15 min, open this screen: the log shows on time / minutes late / missed, and what woke the app.",
                "Repeat with the app swiped away from the app switcher, and once with the ring out of range for a few minutes.",
                "Write the results in the test log. Don't count background delivery as working until it passes here.",
            ].enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).").font(EFont.body(13, .bold)).foregroundStyle(EColor.textSecondary)
                    Text(step).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
            }
        }
        .padding(16).background(Color(hex: "#17131F"), in: RoundedRectangle(cornerRadius: 18))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(EFont.body(13)).foregroundStyle(EColor.textSecondary).frame(width: 84, alignment: .leading)
            Text(value).font(EFont.body(13, .semibold))
        }
    }

    private func color(_ e: ReminderEvent) -> Color {
        switch e.status {
        case "delivered": (e.delaySeconds ?? 0) < 120 ? EColor.success : EColor.warning
        case "missed": EColor.danger
        default: EColor.textSecondary
        }
    }

    private func scheduleTests() {
        let exp = experiences.first
        for minutes in [2, 5, 10] {
            let e = ReminderEvent(ruleID: nil, feeling: exp?.feeling ?? .gratitude, at: Date().addingTimeInterval(TimeInterval(minutes * 60)), experienceID: exp?.id)
            e.isTest = true
            context.insert(e)
            ReminderScheduler.scheduleTestNotification(for: e, experience: exp)
        }
        try? context.save()
    }

    private func clearTests() {
        let ids = tests.map { "emotion.testcue.\($0.id.uuidString)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        for e in tests { context.delete(e) }
        try? context.save()
    }
}
#endif
