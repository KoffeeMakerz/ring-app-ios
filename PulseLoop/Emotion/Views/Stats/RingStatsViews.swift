import SwiftData
import SwiftUI

/// Optional ring stats (steps, heart rate, HRV, sleep) read from PulseLoop's synced store.
/// Shown only for the stats the person switched on in the Ring tab.
@MainActor
struct RingStatsSnapshot {
    struct Day: Identifiable { let date: Date; let value: Double; var id: Date { date } }

    var stepsToday: Int?
    var steps7: [Day] = []
    var hrLatest: (value: Int, at: Date)?
    var hrRestingToday: Int?
    var hr7: [Day] = []
    var hrvLatest: (value: Int, at: Date)?
    var hrv7: [Day] = []
    var sleepLast: (minutes: Int, score: Int?, date: Date)?
    var sleep7: [Day] = []

    var isEmpty: Bool { stepsToday == nil && hrLatest == nil && hrvLatest == nil && sleepLast == nil }

    static func load(_ context: ModelContext) -> RingStatsSnapshot {
        var s = RingStatsSnapshot()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }

        // Steps: one value per day (largest row wins if a day has several sources).
        let acts = (try? context.fetch(FetchDescriptor<ActivityDaily>(predicate: #Predicate { $0.date >= weekStart }))) ?? []
        s.steps7 = days.map { d in Day(date: d, value: Double(acts.filter { cal.isDate($0.date, inSameDayAs: d) }.map(\.steps).max() ?? 0)) }
        s.stepsToday = acts.filter { cal.isDate($0.date, inSameDayAs: today) }.map(\.steps).max()

        // Heart rate and HRV from measurements.
        func measurements(_ kind: MeasurementKind) -> [Measurement] {
            let raw = kind.rawValue
            return (try? context.fetch(FetchDescriptor<Measurement>(
                predicate: #Predicate { $0.kindRaw == raw && $0.timestamp >= weekStart },
                sortBy: [SortDescriptor(\.timestamp)]))) ?? []
        }
        func dailyAverage(_ ms: [Measurement]) -> [Day] {
            days.map { d in
                let v = ms.filter { cal.isDate($0.timestamp, inSameDayAs: d) }.map(\.value)
                return Day(date: d, value: v.isEmpty ? 0 : v.reduce(0, +) / Double(v.count))
            }
        }
        let hr = measurements(.heartRate).filter { $0.value > 30 && $0.value < 220 }
        if let last = hr.last { s.hrLatest = (Int(last.value.rounded()), last.timestamp) }
        s.hrRestingToday = hr.filter { cal.isDate($0.timestamp, inSameDayAs: today) }.map { Int($0.value.rounded()) }.min()
        s.hr7 = dailyAverage(hr)
        let hrv = measurements(.hrv).filter { $0.value > 0 }
        if let last = hrv.last { s.hrvLatest = (Int(last.value.rounded()), last.timestamp) }
        s.hrv7 = dailyAverage(hrv)

        // Sleep: newest session per night.
        let sleeps = (try? context.fetch(FetchDescriptor<SleepSession>(
            predicate: #Predicate { $0.date >= weekStart }, sortBy: [SortDescriptor(\.endAt)]))) ?? []
        if let last = sleeps.last { s.sleepLast = (last.totalMinutes, last.score, last.date) }
        s.sleep7 = days.map { d in Day(date: d, value: Double(sleeps.filter { cal.isDate($0.date, inSameDayAs: d) }.map(\.totalMinutes).reduce(0, +))) }
        return s
    }
}

/// Ring tab section: one card per enabled stat.
struct RingStatsSection: View {
    let profile: EmotionProfile
    @Environment(\.modelContext) private var context
    @Environment(EmotionServices.self) private var services
    @State private var snap = RingStatsSnapshot()
    @State private var syncing = false
    @State private var measuring: String?
    @State private var dataChange = PulseDataChange.shared

    private var coordinator: RingSyncCoordinator { services.coordinator }
    private var realRingConnected: Bool { services.client.state == .connected }
    private var caps: Set<WearableCapability> { services.client.activeCapabilities }
    private func isStale(_ d: Date?) -> Bool { d.map { Date().timeIntervalSince($0) > 2 * 3600 } ?? true }

    /// "Colmi R02 · connected · last synced 2 min ago"
    private var statusLine: String {
        if services.haptics.usesSimulator { return "Simulated ring on — stats come only from a real ring" }
        let name = services.client.activeWearableModel?.displayName ?? "Ring"
        guard realRingConnected else { return "\(name) · not connected" }
        if coordinator.isSyncing || syncing { return "\(name) · syncing… \(coordinator.syncStage ?? "")" }
        if let err = coordinator.syncError { return "\(name) · last sync failed: \(err)" }
        if let at = coordinator.lastSyncAt { return "\(name) · last synced \(at.formatted(.relative(presentation: .named)))" }
        return "\(name) · connected, not synced yet"
    }

    private var anyOn: Bool { profile.statsHeart || profile.statsSleep || profile.statsActivity }

    var body: some View {
        if anyOn {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("Your stats")
                    Spacer()
                    Button(syncing ? "Syncing…" : "Sync now") {
                        syncing = true
                        Task {
                            await services.coordinator.pullToRefresh()
                            try? await Task.sleep(for: .seconds(3))
                            snap = .load(context); syncing = false
                        }
                    }
                    .buttonStyle(TextLinkButtonStyle()).disabled(syncing)
                }
                Text(statusLine).font(EFont.body(12)).foregroundStyle(coordinator.syncError != nil ? EColor.warning : EColor.textSecondary)
                if snap.isEmpty {
                    InfoNote(icon: "arrow.triangle.2.circlepath", text: services.haptics.usesSimulator
                             ? "Stats come from a real ring. Turn off the simulated ring and connect yours."
                             : "No data from your ring yet. Keep it connected and tap Sync now; steps and heart data appear after the first sync.")
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    if profile.statsActivity {
                        StatCard(title: "Steps today", value: snap.stepsToday.map { $0.formatted() } ?? "—", unit: "",
                                 note: "7-day", days: snap.steps7, color: Color(hex: "#6FD6A1"))
                    }
                    if profile.statsHeart {
                        StatCard(title: "Heart rate", value: snap.hrLatest.map { "\($0.value)" } ?? "—", unit: "bpm",
                                 note: ago(snap.hrLatest?.at).map { "updated \($0)" } ?? "no reading yet",
                                 days: snap.hr7, color: Color(hex: "#F27A9B"), stale: snap.hrLatest != nil && isStale(snap.hrLatest?.at))
                        StatCard(title: "HRV", value: snap.hrvLatest.map { "\($0.value)" } ?? "—", unit: "ms",
                                 note: ago(snap.hrvLatest?.at).map { "updated \($0)" } ?? "no reading yet",
                                 days: snap.hrv7, color: Color(hex: "#7FB2F0"), stale: snap.hrvLatest != nil && isStale(snap.hrvLatest?.at))
                    }
                    if profile.statsSleep {
                        StatCard(title: "Sleep", value: snap.sleepLast.map { "\($0.minutes / 60)h \($0.minutes % 60)m" } ?? "—", unit: "",
                                 note: snap.sleepLast?.score.map { "score \($0)" } ?? "last night", days: snap.sleep7, color: Color(hex: "#B892FF"))
                    }
                }
                if profile.statsHeart, realRingConnected, !services.haptics.usesSimulator {
                    HStack(spacing: 8) {
                        if caps.contains(.manualHeartRate) {
                            measureButton("Measure heart rate", key: "hr") { _ = await coordinator.measureHR() }
                        }
                        if caps.contains(.manualHrv) {
                            measureButton("Measure HRV", key: "hrv") { _ = await coordinator.measureHRV() }
                        }
                    }
                    if isStale(snap.hrLatest?.at) {
                        Text("Your ring normally measures heart rate every few minutes in the background. If the last reading stays hours old after a sync, the ring may not be recording — measure once now and tell us which ring you have.")
                            .font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                    }
                }
            }
            .onAppear { snap = .load(context) }
            .onChange(of: dataChange.token) { _, _ in snap = .load(context) }
        }
    }

    private func measureButton(_ title: String, key: String, run: @escaping () async -> Void) -> some View {
        Button(measuring == key ? "Measuring… keep still" : title) {
            measuring = key
            Task {
                await run()
                try? await Task.sleep(for: .seconds(1))
                snap = .load(context)
                measuring = nil
            }
        }
        .buttonStyle(SecondaryButtonStyle(height: 42))
        .disabled(measuring != nil)
    }

    private func ago(_ date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(.relative(presentation: .named))
    }
}

/// One stat with a 7-day mini bar chart.
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let note: String?
    let days: [RingStatsSnapshot.Day]
    let color: Color
    var stale = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(EFont.display(24))
                if !unit.isEmpty { Text(unit).font(EFont.body(12)).foregroundStyle(EColor.textSecondary) }
            }
            if let note {
                Text(note).font(EFont.body(11)).foregroundStyle(stale ? EColor.warning : EColor.textMuted).lineLimit(1)
            }
            let top = max(days.map(\.value).max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(days) { d in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(d.value > 0 ? color.opacity(Calendar.current.isDateInToday(d.date) ? 1 : 0.45) : EColor.line)
                        .frame(height: max(3, 30 * d.value / top))
                }
            }
            .frame(height: 30, alignment: .bottom)
            .accessibilityHidden(true)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).eCard(radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Compact line on Home: "6,240 steps · 64 bpm · HRV 42 ms". Tapping opens the Ring tab.
struct HomeStatsStrip: View {
    let profile: EmotionProfile
    var onTap: () -> Void
    @Environment(\.modelContext) private var context
    @State private var snap = RingStatsSnapshot()
    @State private var dataChange = PulseDataChange.shared

    var body: some View {
        let parts = items
        if !parts.isEmpty {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ForEach(parts, id: \.label) { item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.value).font(EFont.body(15, .bold))
                            Text(item.label).font(EFont.body(11)).foregroundStyle(EColor.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).eCard()
            }
            .buttonStyle(.plain)
        }
        Color.clear.frame(height: 0)
            .onAppear { snap = .load(context) }
            .onChange(of: dataChange.token) { _, _ in snap = .load(context) }
    }

    private var items: [(label: String, value: String)] {
        var r: [(label: String, value: String)] = []
        if profile.statsActivity, let s = snap.stepsToday { r.append(("steps today", s.formatted())) }
        if profile.statsHeart, let h = snap.hrLatest { r.append(("bpm", "\(h.value)")) }
        if profile.statsHeart, let v = snap.hrvLatest { r.append(("HRV ms", "\(v.value)")) }
        if profile.statsSleep, let sl = snap.sleepLast { r.append(("sleep", "\(sl.minutes / 60)h \(sl.minutes % 60)m")) }
        return r
    }
}
