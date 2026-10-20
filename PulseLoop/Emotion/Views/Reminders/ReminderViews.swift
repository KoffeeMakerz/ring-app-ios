import SwiftData
import SwiftUI

/// 4.1 Reminders.
struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ReminderRule.createdAt) private var rules: [ReminderRule]
    @Query(sort: \ReminderEvent.scheduledAt) private var events: [ReminderEvent]
    @Query private var profiles: [EmotionProfile]
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]
    @State private var editing: ReminderRule?
    @State private var showQuiet = false

    private func experience(for rule: ReminderRule) -> Experience? { experiences.first { $0.id == rule.experienceID } }

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
                        ArcDots(feelings: experience(for: rule)?.feelings ?? [rule.feeling], size: 9)
                        Button { editing = rule } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(experience(for: rule)?.title ?? rule.feeling.name).font(EFont.body(15, .semibold))
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
                Button {
                    let exp = experiences.first
                    let r = ReminderRule(feeling: exp?.feeling ?? profiles.first?.activeFeeling ?? .gratitude)
                    r.experienceID = exp?.id
                    context.insert(r); try? context.save(); editing = r
                } label: {
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
                InfoNote(icon: "dot.radiowaves.left.and.right", text: "At each reminder the app sends your vision's touches to the ring, and a phone notification as well. " + SetTimesEditor.iPhoneTimingNote)
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
        r.randomTimes ? "\(r.perDay) a day · spread · \(hm(r.windowStartMinutes))–\(hm(r.windowEndMinutes))"
            : "\(r.fixedMinutes.map(hm).joined(separator: ", ")) · \(daysLabel(r.fixedDays))"
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
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]
    @State private var start = Date()
    @State private var end = Date()
    @State private var fixedTime = Date()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(experiences.isEmpty ? "Feeling" : "Bring back")
                    FlowLayout(spacing: 8) {
                        ForEach(experiences) { e in
                            Chip(title: e.title, dot: e.feeling.color, selected: rule.experienceID == e.id, selectedColor: e.feeling.color) {
                                rule.experienceID = e.id; rule.feelingRaw = e.feeling.rawValue
                            }
                        }
                        ForEach(Feeling.allCases) { f in
                            Chip(title: f.name, dot: f.color, selected: rule.experienceID == nil && rule.feeling == f, selectedColor: f.color) {
                                rule.experienceID = nil; rule.feelingRaw = f.rawValue
                            }
                        }
                    }
                    Picker("Style", selection: $rule.randomTimes) {
                        Text("Spread through the day").tag(true)
                        Text("At a set time").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if rule.randomTimes {
                        ReminderEditor(perDay: $rule.perDay, start: $start, end: $end, random: .constant(true), checkIn: $rule.checkInAfter)
                    } else {
                        DatePicker("Time", selection: $fixedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                        SectionLabel("Repeat")
                        DaysPicker(days: Binding(get: { rule.fixedDays.count == 7 ? rule.fixedDays : Array(repeating: true, count: 7) },
                                                 set: { rule.fixedDays = $0 }))
                        InfoNote(icon: "info.circle", text: SetTimesEditor.iPhoneTimingNote)
                    }
                }
                .padding(20)
            }
            .emotionScreen()
            .navigationTitle("Schedule").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        rule.windowStartMinutes = minutes(start); rule.windowEndMinutes = minutes(end)
                        if !rule.randomTimes { rule.fixedMinutes = [minutes(fixedTime)] }
                        try? context.save(); ReminderScheduler.rebuild(context: context); dismiss()
                    }
                }
            }
            .onAppear {
                start = dateFromMinutes(rule.windowStartMinutes); end = dateFromMinutes(rule.windowEndMinutes)
                fixedTime = dateFromMinutes(rule.fixedMinutes.first ?? 9 * 60)
            }
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
    @Query private var experiences: [Experience]

    private var experience: Experience? { experiences.first { $0.id == request.experienceID } }

    var body: some View {
        let f = request.feeling
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                if let exp = experience {
                    TouchGlyph(pattern: exp.touchSequence, color: f.color, scale: 0.02, height: 14, maxWidth: 300)
                    Text("\(exp.title.uppercased()) · \(Date().formatted(date: .omitted, time: .shortened))").font(EFont.label).tracking(1.2).foregroundStyle(f.color)
                    Text(exp.visionPoints.first.map { "Picture it: \($0)." } ?? "Picture your vision, already real.")
                        .font(EFont.display(26, .medium)).multilineTextAlignment(.center)
                    ArcChips(feelings: exp.feelings)
                } else {
                    TouchGlyph(pattern: f.touch, color: f.color, scale: 0.04, height: 18)
                    Text("\(f.name.uppercased()) CUE · \(Date().formatted(date: .omitted, time: .shortened))").font(EFont.label).tracking(1.2).foregroundStyle(f.color)
                    Text(f.cuePrompt).font(EFont.display(28, .medium)).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28).padding(.top, 56)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text("A few words (optional)").font(EFont.body(14, .semibold))
                TextField("The sun on my walk…", text: $note)
                    .padding(.horizontal, 16).frame(minHeight: 52).background(EColor.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(EColor.line, lineWidth: 1.5))
                Text(experience != nil ? "Did it feel real for a moment?" : "Did the buzz bring the feeling?").font(EFont.body(14, .semibold))
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


// MARK: Set times (alarm-style list + picker sheet)

/// One "at set time" reminder being edited before it becomes a `ReminderRule`.
struct SetTime: Identifiable, Hashable {
    var id = UUID()
    var minutes: Int
    var days: [Bool] = Array(repeating: true, count: 7)   // Monday first
    var on = true
    static let weekdays: [Bool] = [true, true, true, true, true, false, false]
}

/// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
func daysLabel(_ days: [Bool]) -> String {
    let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let d = days.count == 7 ? days : Array(repeating: true, count: 7)
    if d.allSatisfy({ $0 }) { return "Every day" }
    if d == SetTime.weekdays { return "Weekdays" }
    if d == [false, false, false, false, false, true, true] { return "Weekends" }
    if !d.contains(true) { return "No days picked" }
    return names.indices.filter { d[$0] }.map { names[$0] }.joined(separator: ", ")
}

struct SetTimesEditor: View {
    @Binding var times: [SetTime]
    @State private var editing: SetTime?
    static let maxTimes = 6
    /// Timed cues are sent by the app; iOS only lets it run when the system wakes it, so they can drift.
    static let iPhoneTimingNote = "On iPhone, a cue can arrive a few minutes before or after the time you set."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Your times")
                Spacer()
                Text("\(times.count) of \(Self.maxTimes)").font(EFont.body(12)).foregroundStyle(EColor.textMuted)
            }
            .padding(.bottom, 2)
            ForEach($times) { $t in
                HStack(spacing: 8) {
                    Button { editing = t } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hm(t.minutes)).font(EFont.display(30)).opacity(t.on ? 1 : 0.45)
                            Text(daysLabel(t.days) + (t.on ? "" : " · off")).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit \(hm(t.minutes)), \(daysLabel(t.days))")
                    Toggle("On", isOn: $t.on).labelsHidden().tint(EColor.accent)
                }
                .padding(.horizontal, 16).eCard(radius: 18)
            }
            if times.count < Self.maxTimes {
                Button { editing = SetTime(minutes: 9 * 60) } label: {
                    Label("Add a time", systemImage: "plus").font(EFont.body(15, .bold)).foregroundStyle(EColor.accent)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 16)
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $editing) { t in
            let isNew = !times.contains { $0.id == t.id }
            SetTimeSheet(time: t, isNew: isNew) { result in
                if let i = times.firstIndex(where: { $0.id == result.id }) { times[i] = result } else { times.append(result) }
                times.sort { $0.minutes < $1.minutes }
            } onDelete: {
                times.removeAll { $0.id == t.id }
            }
        }
    }
}

struct SetTimeSheet: View {
    @State var time: SetTime
    let isNew: Bool
    var onSave: (SetTime) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker("Time", selection: Binding(get: { dateFromMinutes(time.minutes) }, set: { time.minutes = minutes($0) }), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                SectionLabel("Repeat")
                DaysPicker(days: $time.days)
                Text("Your ring will play your vision's touches at \(hm(time.minutes)), \(daysLabel(time.days).lowercased()).")
                    .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                if !isNew {
                    Button("Delete this time", role: .destructive) { onDelete(); dismiss() }
                        .font(EFont.body(15, .bold)).foregroundStyle(EColor.danger)
                        .frame(maxWidth: .infinity, minHeight: 48).background(EColor.cardRaised, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .emotionScreen()
            .navigationTitle(isNew ? "Add a time" : "Edit time").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(time); dismiss() }.fontWeight(.bold).disabled(!time.days.contains(true)) }
            }
        }
        .presentationDetents([.large])
    }
}

/// M T W T F S S toggles plus Every day / Weekdays / Weekends shortcuts.
struct DaysPicker: View {
    @Binding var days: [Bool]
    private let short = ["M", "T", "W", "T", "F", "S", "S"]
    private let full = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let on = days.indices.contains(i) && days[i]
                    Button {
                        if days.count != 7 { days = Array(repeating: true, count: 7) }
                        days[i].toggle()
                    } label: {
                        Text(short[i]).font(EFont.body(14, .bold))
                            .foregroundStyle(on ? EColor.onAccent : EColor.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(on ? EColor.accent : EColor.cardRaised, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(full[i])
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                preset("Every day", Array(repeating: true, count: 7))
                preset("Weekdays", SetTime.weekdays)
                preset("Weekends", [false, false, false, false, false, true, true])
            }
        }
    }
    private func preset(_ title: String, _ value: [Bool]) -> some View {
        Button(title) { days = value }
            .font(EFont.body(13, .semibold)).foregroundStyle(EColor.text)
            .padding(.horizontal, 14).frame(height: 36)
            .background(days == value ? EColor.cardRaised : .clear, in: Capsule())
            .overlay(Capsule().stroke(EColor.line))
    }
}
