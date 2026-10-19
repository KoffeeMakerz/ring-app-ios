import SwiftData
import SwiftUI

/// 4.1 Reminders.
struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReminderRule.createdAt) private var rules: [ReminderRule]
    @Query(sort: \ReminderEvent.scheduledAt) private var events: [ReminderEvent]
    @Query private var profiles: [EmotionProfile]
    @State private var editing: ReminderRule?
    @State private var showQuiet = false

    private var today: [ReminderEvent] { events.filter { Calendar.current.isDateInToday($0.scheduledAt) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let profile = profiles.first {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.remindersPaused ? "Ring reminders paused" : "Ring reminders on").font(EFont.body(16, .bold))
                            Text(profile.remindersPaused ? "Until \(profile.pausedUntil?.formatted(date: .omitted, time: .shortened) ?? "you resume")" : "Up to \(profile.dailyCap) buzzes a day")
                                .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Button(profile.remindersPaused ? "Resume" : "Pause 1 h") {
                            profile.remindersPaused.toggle()
                            profile.pausedUntil = profile.remindersPaused ? Date().addingTimeInterval(3600) : nil
                            try? context.save()
                            ReminderScheduler.rebuild(context: context)
                        }
                        .font(EFont.body(13, .semibold)).foregroundStyle(EColor.text)
                        .padding(.horizontal, 14).frame(height: 36).background(EColor.cardRaised, in: Capsule())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14).eCard()
                }
                SectionLabel("Schedules").padding(.top, 10)
                ForEach(rules) { rule in
                    HStack(spacing: 12) {
                        Circle().fill(rule.feeling.color).frame(width: 10, height: 10)
                        Button { editing = rule } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.feeling.name).font(EFont.body(15, .semibold))
                                Text(describe(rule)).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Toggle("", isOn: Binding(get: { rule.enabled }, set: { rule.enabled = $0; try? context.save(); ReminderScheduler.rebuild(context: context) }))
                            .labelsHidden().tint(EColor.accent)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 64).eCard(radius: 18)
                    .contextMenu { Button("Delete", role: .destructive) { context.delete(rule); try? context.save(); ReminderScheduler.rebuild(context: context) } }
                }
                Button { let r = ReminderRule(feeling: profiles.first?.activeFeeling ?? .gratitude); context.insert(r); try? context.save(); editing = r } label: {
                    Label("Add a schedule", systemImage: "plus").font(EFont.body(14, .semibold)).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 16)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                .buttonStyle(.plain)
                if let profile = profiles.first {
                    Button { showQuiet = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "moon").foregroundStyle(EColor.textSecondary)
                            Text("Quiet hours").font(EFont.body(15, .semibold))
                            Spacer()
                            Text("\(hm(profile.quietStartMinutes))–\(hm(profile.quietEndMinutes))").font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 56).eCard(radius: 18)
                    }
                    .buttonStyle(.plain)
                }
                SectionLabel("Today").padding(.top, 10)
                VStack(spacing: 0) {
                    if today.isEmpty { Text("Nothing scheduled today").font(EFont.body(14)).foregroundStyle(EColor.textSecondary).frame(maxWidth: .infinity, minHeight: 52) }
                    ForEach(today) { event in
                        HStack(spacing: 12) {
                            Text(event.scheduledAt.formatted(date: .omitted, time: .shortened)).font(EFont.body(14)).foregroundStyle(EColor.textSecondary).frame(width: 64, alignment: .leading)
                            Text(statusText(event)).font(EFont.body(14, event.scheduledAt <= Date() ? .semibold : .regular))
                                .foregroundStyle(event.scheduledAt <= Date() ? EColor.text : EColor.textSecondary)
                            Spacer()
                            if let felt = event.feltRating { Text(["No", "A little", "Yes"][min(max(felt, 0), 2)]).font(EFont.body(13, .bold)).foregroundStyle(EColor.success) }
                        }
                        .frame(minHeight: 52)
                        if event.id != today.last?.id { Divider().overlay(EColor.line) }
                    }
                }
                .padding(.horizontal, 16).eCard(radius: 18)
                InfoNote(icon: "dot.radiowaves.left.and.right", text: "Reminders are written to your ring when it's connected, so they still arrive with your phone locked. A phone notification is sent as a backup.")
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Reminders").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { rule in RuleEditorSheet(rule: rule) }
        .sheet(isPresented: $showQuiet) { if let p = profiles.first { QuietHoursSheet(profile: p) } }
        .onAppear { ReminderScheduler.rebuild(context: context) }
    }

    private func describe(_ r: ReminderRule) -> String {
        r.randomTimes ? "\(r.perDay) a day · random · \(hm(r.windowStartMinutes))–\(hm(r.windowEndMinutes))" : "\(r.fixedMinutes.map(hm).joined(separator: ", ")) · fixed"
    }

    private func statusText(_ e: ReminderEvent) -> String {
        if e.scheduledAt > Date() { return "Scheduled · \(e.feeling.name)" }
        switch e.status {
        case "missed": return "Missed · ring was out of range"
        case "delivered": return e.feltRating != nil ? "Delivered · you checked in" : "Delivered"
        default: return "Delivered · \(e.feeling.name)"
        }
    }
}

func hm(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }

struct RuleEditorSheet: View {
    @Bindable var rule: ReminderRule
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var end = Date()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel("Feeling")
                    FlowLayout(spacing: 8) {
                        ForEach(Feeling.allCases) { f in Chip(title: f.name, dot: f.color, selected: rule.feeling == f, selectedColor: f.color) { rule.feelingRaw = f.rawValue } }
                    }
                    ReminderEditor(perDay: $rule.perDay, start: $start, end: $end, random: $rule.randomTimes, checkIn: $rule.checkInAfter)
                }
                .padding(20)
            }
            .emotionScreen()
            .navigationTitle("Schedule").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        rule.windowStartMinutes = minutes(start); rule.windowEndMinutes = minutes(end)
                        if !rule.randomTimes, rule.fixedMinutes.isEmpty { rule.fixedMinutes = [rule.windowStartMinutes] }
                        try? context.save(); ReminderScheduler.rebuild(context: context); dismiss()
                    }
                }
            }
            .onAppear { start = dateFromMinutes(rule.windowStartMinutes); end = dateFromMinutes(rule.windowEndMinutes) }
        }
    }
}

struct QuietHoursSheet: View {
    @Bindable var profile: EmotionProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var end = Date()
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Quiet from", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: $end, displayedComponents: .hourAndMinute)
                Stepper("Up to \(profile.dailyCap) buzzes a day", value: $profile.dailyCap, in: 1...12)
            }
            .scrollContentBackground(.hidden)
            .emotionScreen()
            .navigationTitle("Quiet hours").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        profile.quietStartMinutes = minutes(start); profile.quietEndMinutes = minutes(end)
                        try? context.save(); ReminderScheduler.rebuild(context: context); dismiss()
                    }
                }
            }
            .onAppear { start = dateFromMinutes(profile.quietStartMinutes); end = dateFromMinutes(profile.quietEndMinutes) }
        }
        .presentationDetents([.medium])
    }
}

/// 4.2 Cue received — one-breath reflection after a reminder.
struct CueReceivedView: View {
    let request: CueRequest
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EmotionRouter.self) private var router
    @State private var note = ""
    @State private var felt: Int? = nil

    var body: some View {
        let f = request.feeling
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                TouchGlyph(pattern: f.touch, color: f.color, scale: 0.04, height: 18)
                Text("\(f.name.uppercased()) CUE · \(Date().formatted(date: .omitted, time: .shortened))").font(EFont.label).tracking(1.2).foregroundStyle(f.color)
                Text(f.cuePrompt).font(EFont.display(28, .medium)).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28).padding(.top, 56)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text("A few words (optional)").font(EFont.body(14, .semibold))
                TextField("The sun on my walk…", text: $note)
                    .padding(.horizontal, 16).frame(minHeight: 52).background(EColor.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(EColor.line, lineWidth: 1.5))
                Text("Did the buzz bring the feeling?").font(EFont.body(14, .semibold))
                HStack(spacing: 8) {
                    ForEach([(2, "Yes"), (1, "A little"), (0, "Not really")], id: \.0) { value, title in
                        Button { felt = value } label: {
                            Text(title).font(EFont.body(14, felt == value ? .bold : .semibold))
                                .foregroundStyle(felt == value ? EColor.onAccent : EColor.text)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(felt == value ? f.color : EColor.cardRaised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Done") { save(); dismiss() }.buttonStyle(PrimaryButtonStyle(color: EColor.text, foreground: EColor.ground, height: 54))
                HStack(spacing: 24) {
                    Button("Fewer reminders") { save(); dismiss(); router.tab = .home; router.homePath.append(ERoute.reminders) }
                    Button("Mute today") {
                        let p = context.emotionProfile()
                        p.remindersPaused = true
                        p.pausedUntil = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
                        save(); ReminderScheduler.rebuild(context: context); dismiss()
                    }
                }
                .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(EColor.ground, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        }
        .foregroundStyle(EColor.text)
        .background(f.ground.ignoresSafeArea())
    }

    private func save() {
        let now = Date()
        let all = (try? context.fetch(FetchDescriptor<ReminderEvent>())) ?? []
        if let event = all.filter({ $0.scheduledAt <= now && $0.feelingRaw == request.feeling.rawValue }).max(by: { $0.scheduledAt < $1.scheduledAt }) {
            event.status = "delivered"
            event.deliveredAt = event.deliveredAt ?? now
            event.feltRating = felt
            event.note = note.isEmpty ? nil : note
        }
        try? context.save()
    }
}
