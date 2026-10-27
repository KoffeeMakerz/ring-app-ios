import SwiftUI
import WatchKit

// MARK: Experiences

struct ExperiencesView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            if store.experiences.isEmpty {
                Text("Create an experience in Kinnora on your iPhone and it appears here.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.experiences) { exp in
                NavigationLink(value: WatchRoute.experience(exp.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exp.title).font(.headline).lineLimit(2)
                        HStack(spacing: 4) {
                            ForEach(Array(exp.colors.enumerated()), id: \.offset) { _, c in
                                Circle().fill(c).frame(width: 8, height: 8)
                            }
                            Text(exp.feelings.map { WatchFeeling.named($0).name }.joined(separator: " → "))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("Experiences")
    }
}

struct ExperienceDetailView: View {
    let id: String
    @EnvironmentObject var store: WatchStore
    @EnvironmentObject var session: WatchSession
    @State private var phoneNote: String?

    var body: some View {
        if let exp = store.experience(id) {
            ScrollView {
                VStack(spacing: 10) {
                    Bloom(color: exp.feeling(at: 0).color, breathing: true).frame(height: 70)
                    Text(exp.title).font(.headline).multilineTextAlignment(.center)
                    Text("\(exp.feelings.map { WatchFeeling.named($0).name }.joined(separator: " → ")) · \(max(1, exp.durationS / 60)) min")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    NavigationLink(value: WatchRoute.play(exp.id)) {
                        Label("Play here", systemImage: "applewatch").frame(maxWidth: .infinity)
                    }
                    .tint(exp.feeling(at: 0).color)
                    Button {
                        let now = session.startOnPhone(experienceID: exp.id)
                        phoneNote = now ? "Starting on your iPhone…" : "Your iPhone will start it when it's back in reach."
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Label("Play on iPhone", systemImage: "iphone").frame(maxWidth: .infinity)
                    }
                    if let phoneNote {
                        Text(phoneNote).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Text("Play here: the touches and feelings on your wrist, no music. Play on iPhone: the song and images there, touches on your ring and watch.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Experience")
        } else {
            Text("This experience isn't on the watch any more.").font(.footnote)
        }
    }
}

/// Plays an experience on the wrist: a breathing bloom in the current feeling's colour, and each
/// cue's touch at its moment. Keeps the app awake while it plays.
struct PlayerView: View {
    let id: String
    @EnvironmentObject var store: WatchStore
    @EnvironmentObject var keepAwake: KeepAwake
    @Environment(\.dismiss) private var dismiss
    @State private var elapsed: Double = 0
    @State private var nextCue = 0
    @State private var finished = false
    @State private var startedAwake = false
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        if let exp = store.experience(id) {
            let feeling = exp.feeling(at: elapsed)
            VStack(spacing: 6) {
                if finished {
                    Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(feeling.color)
                    Text("Well done").font(.headline)
                    Text("You felt \(exp.feelings.map { WatchFeeling.named($0).name.lowercased() }.joined(separator: ", then "))")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Done") { dismiss() }
                } else {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                        Circle().trim(from: 0, to: exp.durationS > 0 ? min(1, elapsed / Double(exp.durationS)) : 0)
                            .stroke(feeling.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Bloom(color: feeling.color, breathing: true).padding(14)
                    }
                    .frame(height: 110)
                    Text("Feel \(feeling.name.lowercased())").font(.headline).foregroundStyle(feeling.color)
                    Text(timeLeft(exp)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .navigationTitle(exp.title)
            .onReceive(timer) { _ in tick(exp) }
            .onAppear {
                if !keepAwake.isOn { keepAwake.start(); startedAwake = true }
            }
            .onDisappear { if startedAwake { keepAwake.stop() } }
        }
    }

    private func tick(_ exp: WatchExperience) {
        guard !finished else { return }
        elapsed += 0.25
        while nextCue < exp.cues.count, Double(exp.cues[nextCue].at) <= elapsed {
            let cue = exp.cues[nextCue]
            HapticPlayer.play(Pattern(name: cue.feeling, durationsMs: cue.durations))
            nextCue += 1
        }
        if elapsed >= Double(exp.durationS) {
            finished = true
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func timeLeft(_ exp: WatchExperience) -> String {
        let left = max(0, exp.durationS - Int(elapsed))
        return String(format: "%d:%02d left", left / 60, left % 60)
    }
}

// MARK: Reminders

struct RemindersView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            if store.upcoming.isEmpty {
                Text("No reminders planned. Set them in Kinnora on your iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(store.upcoming.prefix(20)) { reminder in
                HStack(spacing: 8) {
                    Circle().fill(WatchFeeling.named(reminder.feeling).color).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(reminder.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(reminder.title).font(.footnote).lineLimit(2)
                    }
                }
            }
            Section {
                Text("Each reminder taps your wrist with its feeling. Tap Start on it to feel it now. Times and feelings are set on your iPhone.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Reminders")
    }
}

// MARK: Feelings

struct FeelingsView: View {
    var body: some View {
        List(WatchFeeling.all) { feeling in
            NavigationLink(value: WatchRoute.feel(feeling.id)) {
                HStack {
                    Circle().fill(feeling.color).frame(width: 10, height: 10)
                    Text(feeling.name)
                }
            }
        }
        .navigationTitle("Feel a touch")
    }
}

/// One feeling: the bloom in its colour and its touch, played on arrival and on tap.
struct FeelView: View {
    let feeling: WatchFeeling

    var body: some View {
        VStack(spacing: 8) {
            Bloom(color: feeling.color, breathing: true).frame(height: 100)
            Text(feeling.name).font(.headline).foregroundStyle(feeling.color)
            Button("Feel it again") { HapticPlayer.play(feeling.pattern) }
        }
        .navigationTitle(feeling.name)
        .onAppear { HapticPlayer.play(feeling.pattern) }
    }
}

// MARK: Bloom

/// Six soft petals that slowly open and close: in for 4 s, out for 7 s, like Kinnora's breathing.
struct Bloom: View {
    let color: Color
    var breathing = true
    @State private var open = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(color.opacity(0.45))
                    .frame(width: 34, height: 34)
                    .offset(y: open ? -16 : -4)
                    .rotationEffect(.degrees(Double(i) * 60 + (open ? 30 : 0)))
            }
            Circle().fill(color.opacity(0.9)).frame(width: 12, height: 12)
        }
        .scaleEffect(open ? 1.15 : 0.7)
        .onAppear { if breathing { cycle() } }
        .accessibilityHidden(true)
    }

    private func cycle() {
        withAnimation(.easeInOut(duration: 4)) { open = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeInOut(duration: 7)) { open = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { cycle() }
        }
    }
}
