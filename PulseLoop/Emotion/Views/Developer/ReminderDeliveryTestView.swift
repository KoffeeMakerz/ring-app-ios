#if DEBUG
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Developer-only (debug builds): checks how reminder cues actually reach a real ring on this
/// iPhone — on time, late, or missed — with the phone locked. Not shown in release builds.
struct ReminderDeliveryTestView: View {
    @Environment(\.modelContext) private var context
    @Environment(EmotionServices.self) private var services
    @Query(sort: \ReminderEvent.scheduledAt, order: .reverse) private var events: [ReminderEvent]
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]

    @State private var notif = NotificationDiagnostics()
    private var recent: [ReminderEvent] { Array(events.filter { $0.scheduledAt <= Date().addingTimeInterval(3600) }.prefix(40)) }
    private var tests: [ReminderEvent] { events.filter(\.isTest) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                notificationCard
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

                HStack {
                    SectionLabel("Wake log")
                    Spacer()
                    Button("Clear") { services.dispatcher?.clearWakeLog() }.buttonStyle(TextLinkButtonStyle())
                }
                .padding(.top, 4)
                Text("Every time iOS let the app check for cues. Entries marked “background/locked” prove the ring woke the app while the phone was locked.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                VStack(alignment: .leading, spacing: 6) {
                    let log = services.dispatcher?.wakeLog ?? []
                    if log.isEmpty { Text("No wakes logged yet").font(EFont.body(13)).foregroundStyle(EColor.textSecondary) }
                    ForEach(Array(log.prefix(30).enumerated()), id: \.offset) { _, line in
                        Text(line).font(EFont.mono(11))
                            .foregroundStyle(line.contains("background") ? EColor.success : line.contains("SENT") ? EColor.text : EColor.textSecondary)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard(radius: 18)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Reminder delivery test").navigationBarTitleDisplayMode(.inline)
        .task { await notif.refresh() }
        .refreshable { await notif.refresh() }
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phone notifications").font(EFont.body(14, .bold))
            row("Permission", notif.permission)
            row("Lock screen", notif.lockScreen)
            row("Style", notif.style)
            row("Queued", "\(notif.pendingCues) reminder · \(notif.pendingTests) test notifications waiting in iOS")
            row("Shown", "\(notif.deliveredOurs) of ours currently in Notification Centre")
            Text("If permission or lock screen isn't “On”, iOS won't show cues while locked. Also check Focus / Sleep mode.")
                .font(EFont.body(12)).foregroundStyle(EColor.textMuted).padding(.top, 2)
            HStack(spacing: 8) {
                if notif.permission == "Not asked yet" {
                    Button("Ask permission") { ReminderScheduler.requestPermission(); Task { try? await Task.sleep(for: .seconds(2)); await notif.refresh() } }
                        .buttonStyle(SecondaryButtonStyle(height: 40))
                }
                Button("Open iPhone Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                    .buttonStyle(SecondaryButtonStyle(height: 40))
                Button("Refresh") { Task { await notif.refresh() } }.buttonStyle(SecondaryButtonStyle(height: 40))
            }
            .padding(.top, 4)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).eCard(radius: 18)
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
        Task { try? await Task.sleep(for: .milliseconds(500)); await notif.refresh() }
    }

    private func clearTests() {
        defer { Task { await notif.refresh() } }
        let ids = tests.map { "emotion.testcue.\($0.id.uuidString)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        for e in tests { context.delete(e) }
        try? context.save()
    }
}

/// What iOS will do with our notifications, read from the notification centre.
@MainActor
@Observable
final class NotificationDiagnostics {
    var permission = "…"
    var lockScreen = "…"
    var style = "…"
    var pendingCues = 0
    var pendingTests = 0
    var deliveredOurs = 0

    func refresh() async {
        let center = UNUserNotificationCenter.current()
        let s = await center.notificationSettings()
        permission = switch s.authorizationStatus {
        case .authorized: "On"
        case .denied: "Off (denied)"
        case .notDetermined: "Not asked yet"
        case .provisional: "Provisional (delivered quietly)"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }
        lockScreen = s.lockScreenSetting == .enabled ? "On" : s.lockScreenSetting == .disabled ? "Off" : "Not supported"
        style = s.alertStyle == .banner ? "Banners" : s.alertStyle == .alert ? "Alerts" : "None (no banners)"
        let pending = await center.pendingNotificationRequests()
        pendingCues = pending.filter { $0.identifier.hasPrefix("emotion.cue.") }.count
        pendingTests = pending.filter { $0.identifier.hasPrefix("emotion.testcue.") }.count
        let delivered = await center.deliveredNotifications()
        deliveredOurs = delivered.filter { $0.request.identifier.hasPrefix("emotion.") }.count
    }
}
#endif
