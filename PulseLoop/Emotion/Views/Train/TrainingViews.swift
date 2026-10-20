import SwiftData
import SwiftUI

// MARK: Train tab hub

struct TrainHubView: View {
    @Query(sort: \TrainingRecord.completedAt, order: .reverse) private var records: [TrainingRecord]
    @Query private var experiences: [Experience]
    @Environment(EmotionRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Practise emotions").font(EFont.display(28)).padding(.top, 8)
                Text("Five minutes with one feeling and its ring touch. The stronger each link, the more alive your experiences feel.")
                    .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 4)
                ForEach(Feeling.unlockOrder) { feeling in
                    let done = FeelingProgress.sessions(feeling, records)
                    let used = experiences.filter { $0.feelings.contains(feeling) }.count
                    Button { router.push(.trainIntro(feeling)) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) { Circle().fill(feeling.color).frame(width: 10, height: 10); Text(feeling.name).font(EFont.body(16, .bold)) }
                                TouchGlyph(pattern: feeling.touch, color: feeling.color, scale: 0.02, height: 7)
                                HStack(spacing: 8) {
                                    ThinProgress(value: Double(min(done, Feeling.programmeLength)) / Double(Feeling.programmeLength), color: feeling.color).frame(width: 64)
                                    Text("\(min(done, Feeling.programmeLength)) of \(Feeling.programmeLength) · " + (used == 0 ? "not in an experience yet" : "in \(used) \(used == 1 ? "experience" : "experiences")"))
                                        .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                                }
                            }
                            Spacer()
                            Text("Practise").font(EFont.body(13, .bold)).padding(.horizontal, 14).frame(height: 40).background(EColor.cardRaised, in: Capsule())
                        }
                        .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 12).eCard(radius: 18)
                    }
                    .buttonStyle(.plain)
                }
                Button { router.push(.reminders) } label: {
                    Label("Reminders & quiet hours", systemImage: "alarm").font(EFont.body(15, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 16).eCard(radius: 16)
                }
                .buttonStyle(.plain).padding(.top, 6)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }
}

enum FeelingProgress {
    static func sessions(_ feeling: Feeling, _ records: [TrainingRecord]) -> Int {
        records.filter { $0.feelingRaw == feeling.rawValue }.count
    }
}

// MARK: 2.1 Training intro

struct TrainIntroView: View {
    let feeling: Feeling
    var onboarding = false
    var onContinue: (() -> Void)? = nil
    @Query private var records: [TrainingRecord]
    @State private var track: MusicTrack
    @State private var showSession = false
    @State private var showTrackPicker = false

    init(feeling: Feeling, onboarding: Bool = false, onContinue: (() -> Void)? = nil) {
        self.feeling = feeling
        self.onboarding = onboarding
        self.onContinue = onContinue
        _track = State(initialValue: MusicTrack.default(for: feeling))
    }

    var sessionNumber: Int { min(Feeling.programmeLength, FeelingProgress.sessions(feeling, records) + 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if onboarding { EOnboardingHeader(progress: nil) }
            HStack { Spacer(); Text("Session \(sessionNumber) of \(Feeling.programmeLength)").font(EFont.body(13, .semibold)).foregroundStyle(EColor.textSecondary); Spacer() }
            Text("PRACTISE · \(feeling.name.uppercased())").font(EFont.label).tracking(1.2).foregroundStyle(feeling.color).padding(.top, 18)
            Text("Link \(feeling.name.lowercased()) to its touch").font(EFont.display(30)).padding(.top, 6).padding(.bottom, 16)
            Button {} label: {
                VStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 22)).foregroundStyle(EColor.ground)
                        .frame(width: 56, height: 56).background(EColor.text, in: Circle())
                    Text("[GUIDE VIDEO] How training works · 2 min").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160).eCard(EColor.cardRaised)
            }
            .buttonStyle(.plain).accessibilityLabel("Play guide video")
            VStack(alignment: .leading, spacing: 14) {
                stepRow(1, "Settle in · 1 min", "Slow breaths to relax and focus.")
                stepRow(2, "Feel it with music · 4 min", "When the feeling peaks, your ring plays the \(feeling.name.lowercased()) rhythm.")
                stepRow(3, "Check in · 30 s", "Rate how strongly the rhythm brought the feeling back.")
            }
            .padding(.top, 22)
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(track.theme.art).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(EFont.body(14, .semibold))
                    Text("\(track.theme.name) · \(track.durationLabel) · \(track.cueMarkersS.count) ring cues").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                }
                Spacer()
                Button("Change") { showTrackPicker = true }.buttonStyle(TextLinkButtonStyle())
            }
            .padding(.horizontal, 14).padding(.vertical, 12).eCard(radius: 16).padding(.top, 22)
            Spacer()
            Button("Begin session") { showSession = true }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(onboarding ? .hidden : .automatic, for: .navigationBar)
        .fullScreenCover(isPresented: $showSession) {
            TrainingSessionView(request: TrainingRequest(feeling: feeling, experienceID: nil), track: track) { finished in
                showSession = false
                if finished { onContinue?() }
            }
        }
        .sheet(isPresented: $showTrackPicker) {
            TrackPickerSheet(selected: $track)
        }
    }

    private func stepRow(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)").font(EFont.body(13, .bold)).frame(width: 28, height: 28).background(EColor.cardRaised, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(EFont.body(15, .semibold))
                Text(detail).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            }
        }
    }
}

struct TrackPickerSheet: View {
    @Binding var selected: MusicTrack
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(MusicTheme.allCases) { theme in
                    Section(theme.name) {
                        ForEach(MusicTrack.catalog.filter { $0.theme == theme }) { track in
                            Button { selected = track; dismiss() } label: {
                                HStack {
                                    RoundedRectangle(cornerRadius: 8).fill(theme.art).frame(width: 36, height: 36)
                                    VStack(alignment: .leading) {
                                        Text(track.title).foregroundStyle(EColor.text)
                                        Text("\(track.durationLabel) · \(track.cueMarkersS.count) ring cues").font(.caption).foregroundStyle(EColor.textSecondary)
                                    }
                                    Spacer()
                                    if track == selected { Image(systemName: "checkmark").foregroundStyle(EColor.accent) }
                                }
                            }
                        }
                    }
                    .listRowBackground(EColor.card)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Music")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .emotionScreen()
        }
    }
}

// MARK: 2.2 + 2.3 Training session

struct TrainingSessionView: View {
    let request: TrainingRequest
    var track: MusicTrack? = nil
    var onFinish: ((Bool) -> Void)? = nil

    @Environment(EmotionServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [TrainingRecord]

    enum Stage { case settle, feel, reflect }
    @State private var stage: Stage = .settle
    @State private var playback: ExperiencePlayback?
    @State private var experience: Experience?
    @State private var settleLeft = 60
    @State private var rating = 3
    @State private var comfort = "right"

    var feeling: Feeling { request.feeling }

    var body: some View {
        Group {
            switch stage {
            case .settle: settleView
            case .feel: if let playback { feelView(playback) }
            case .reflect: reflectView
            }
        }
        .onAppear(perform: setUp)
        .onDisappear { playback?.stop() }
    }

    private func setUp() {
        if let id = request.experienceID {
            experience = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first
        }
        if let experience { playback = services.playback(for: experience) }
        else { playback = services.playback(feeling: feeling, track: track ?? MusicTrack.default(for: feeling)) }
    }

    private func close(finished: Bool) {
        playback?.stop()
        if let onFinish { onFinish(finished) } else { dismiss() }
    }

    // Settle: 60 s of slow breathing.
    private var settleView: some View {
        VStack(spacing: 24) {
            HStack {
                Button { close(finished: false) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("End session")
                Spacer()
                Text("Step 1 · Settle in").font(EFont.body(13, .semibold)).foregroundStyle(EColor.textSecondary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            BreathCircle(color: feeling.color, inSeconds: 4, outSeconds: 6)
            Text("Breathe in for 4, out for 6").font(EFont.display(22, .medium))
            Text("\(settleLeft) s").font(EFont.body(15)).foregroundStyle(EColor.textSecondary)
            Spacer()
            Button("Skip to music") { startFeel() }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .task {
            while settleLeft > 0, stage == .settle {
                try? await Task.sleep(for: .seconds(1))
                settleLeft -= 1
            }
            if stage == .settle { startFeel() }
        }
    }

    private func startFeel() {
        stage = .feel
        playback?.play()
    }

    /// The touch played once more at check-in: the whole sequence for an experience.
    private var closingTouch: TouchPattern {
        if let experience, experience.feelings.count > 1 { return experience.touchSequence }
        return playback?.touch ?? feeling.touch
    }

    private func feelView(_ p: ExperiencePlayback) -> some View {
        let now = p.currentFeeling
        let multi = p.parts.count > 1
        return ZStack(alignment: .bottom) {
            SlideshowView(experience: experience, index: p.slideIndex, fallback: now, showLabel: false)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { close(finished: false) } label: { Image(systemName: "xmark").frame(width: 44, height: 44).background(EColor.ground.opacity(0.8), in: Circle()) }
                        .accessibilityLabel("End session")
                    Spacer()
                    Text(multi ? "Part \(p.currentPart.index + 1) of \(p.parts.count) · \(now.name)" : "Step 2 · Feel it")
                        .font(EFont.body(13, .semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(EColor.ground.opacity(0.85), in: Capsule())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                if multi {
                    HStack(spacing: 6) {
                        ForEach(p.parts) { part in
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(EColor.ground.opacity(0.8))
                                    Capsule().fill(part.feeling.color).frame(width: geo.size.width * p.fraction(of: part))
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .padding(.top, 12)
                    .accessibilityHidden(true)
                }
                Spacer()
                if experience != nil {
                    HStack(spacing: 8) {
                        Circle().fill(now.color).frame(width: 8, height: 8)
                        Text(now.name).font(EFont.body(13, .bold)).foregroundStyle(now.color)
                    }
                    .padding(.horizontal, 12).frame(height: 30).background(EColor.ground.opacity(0.9), in: Capsule())
                    .padding(.bottom, 10)
                }
                Text(experience != nil ? now.experiencePrompt : feeling.trainingPrompt)
                    .font(EFont.display(25, .medium)).padding(.horizontal, 4).padding(.bottom, 20)
                    .shadow(color: .black.opacity(0.5), radius: 6)
                    .animation(.easeInOut, value: now)
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        TouchGlyph(pattern: p.touch, color: now.color, scale: 0.02, height: 12, maxWidth: 64)
                            .opacity(p.isInCue ? 1 : 0.5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.isInCue ? "Ring is playing \(now.name.lowercased())"
                                 : p.autoCues ? "Next \(now.name.lowercased()) touch coming" : "Tap the ring button when it peaks").font(EFont.body(15, .semibold))
                            Text(p.isInCue ? "Let the feeling peak as it buzzes" : experience != nil ? "Stay with the picture. Feel it as real." : "Notice the feeling as it buzzes")
                                .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .eCard(radius: 18)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(p.isInCue ? now.color : .clear, lineWidth: 1.5))
                    CueTimeline(playback: p, color: now.color)
                    HStack {
                        circleButton("bell.slash", "Mute ring") { p.cuesEnabled.toggle() }
                            .opacity(p.cuesEnabled ? 1 : 0.5)
                        Spacer()
                        if multi {
                            circleButton("backward.end.fill", "Previous part", filled: false) { p.seekToPart(max(0, p.currentPart.index - 1)) }
                        } else {
                            circleButton("gobackward.15", "Back 15 seconds", filled: false) { p.seek(by: -15) }
                        }
                        Spacer()
                        Button { p.toggle() } label: {
                            Image(systemName: p.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 26))
                                .foregroundStyle(EColor.onAccent).frame(width: 72, height: 72).background(now.color, in: Circle())
                        }
                        .accessibilityLabel(p.isPlaying ? "Pause" : "Play")
                        Spacer()
                        if multi {
                            circleButton("forward.end.fill", "Next part", filled: false) { p.seekToPart(min(p.parts.count - 1, p.currentPart.index + 1)) }
                        } else {
                            circleButton("goforward.15", "Forward 15 seconds", filled: false) { p.seek(by: 15) }
                        }
                        Spacer()
                        circleButton("dot.radiowaves.left.and.right", "Replay ring cue now") { p.playCueNow() }
                    }
                    Button("Finish and check in") { p.pause(); stage = .reflect; services.haptics.play(closingTouch) }
                        .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
                }
                .padding(20)
                .background(EColor.ground, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .padding(.horizontal, -20)
            }
            .padding(.horizontal, 20)
        }
        .foregroundStyle(EColor.text)
        .background(EColor.ground)
        .onChange(of: p.progress >= 1) { _, done in if done { stage = .reflect; services.haptics.play(closingTouch) } }
    }

    private func circleButton(_ icon: String, _ label: String, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 52, height: 52)
                .background(filled ? EColor.card : .clear, in: Circle())
        }
        .accessibilityLabel(label)
        .foregroundStyle(EColor.text)
    }

    // Reflect & rate.
    private var reflectView: some View {
        let done = FeelingProgress.sessions(feeling, records)
        let arc = experience?.feelings ?? [feeling]
        let arcText = arc.map { $0.name.lowercased() }.joined(separator: ", then ")
        return VStack(alignment: .leading, spacing: 12) {
            Text(experience.map { "SESSION COMPLETE · \($0.title.uppercased())" } ?? "SESSION \(min(done + 1, Feeling.programmeLength)) COMPLETE")
                .font(EFont.label).tracking(1.2).foregroundStyle(feeling.color).padding(.top, 30).lineLimit(1)
            Text("One last buzz").font(EFont.display(30))
            Text("Your ring played \(arcText) once more, without music. Notice what comes up.")
                .font(EFont.body(15)).foregroundStyle(EColor.textSecondary)
            VStack(alignment: .leading, spacing: 12) {
                Text(experience != nil ? "How real did it feel?" : "How much \(feeling.name.lowercased()) did the rhythm bring back?").font(EFont.body(15, .semibold))
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in
                        Button { rating = n } label: {
                            Text("\(n)").font(EFont.body(17, .bold))
                                .foregroundStyle(rating == n ? EColor.onAccent : EColor.text)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(rating == n ? feeling.color : EColor.cardRaised, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain).accessibilityLabel("Rating \(n) of 5")
                    }
                }
                HStack { Text("Nothing yet"); Spacer(); Text("Strongly") }.font(EFont.body(12)).foregroundStyle(EColor.textMuted)
            }
            .padding(16).eCard()
            VStack(alignment: .leading, spacing: 12) {
                Text("How did the buzz feel?").font(EFont.body(15, .semibold))
                HStack(spacing: 8) {
                    ForEach([("strong", "Too strong"), ("right", "Just right"), ("weak", "Hard to notice")], id: \.0) { key, title in
                        Button { comfort = key } label: {
                            Text(title).font(EFont.body(14, .semibold))
                                .foregroundStyle(comfort == key ? EColor.ground : EColor.text)
                                .padding(.horizontal, 14).frame(minHeight: 40)
                                .background(comfort == key ? EColor.text : EColor.cardRaised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16).eCard()
            if experience == nil {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text("\(feeling.name) practice").font(EFont.body(14, .semibold)); Spacer(); Text("\(min(done + 1, 7)) of 7 sessions").font(EFont.body(13)).foregroundStyle(EColor.textSecondary) }
                    HStack(spacing: 6) { ForEach(0..<7, id: \.self) { i in Capsule().fill(i <= done ? feeling.color : EColor.line).frame(height: 6) } }
                    Text("Each practice strengthens this touch in every experience that uses it.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
                .padding(16)
                .background(Color(hex: "#17131F"), in: RoundedRectangle(cornerRadius: 20))
            } else {
                HStack(spacing: 8) {
                    ForEach(arc) { f in
                        HStack(spacing: 6) { Circle().fill(f.color).frame(width: 8, height: 8); Text(f.name).font(EFont.body(13, .semibold)) }
                            .padding(.horizontal, 10).frame(height: 30).background(f.ground, in: Capsule())
                    }
                }
                Text("Each feeling in this vision also counts as practice for its touch.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            }
            Spacer()
            Button("Save") { saveAndFinish() }.buttonStyle(PrimaryButtonStyle(color: feeling.color))
            Button("Train again") {
                save()
                setUp(); settleLeft = 0; stage = .feel; playback?.play()
            }
            .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
    }

    private func save() {
        for f in experience?.feelings ?? [feeling] {
            context.insert(TrainingRecord(feeling: f, experienceID: request.experienceID, rating: rating, comfort: comfort))
        }
        experience?.lastPlayedAt = Date()
        try? context.save()
    }

    private func saveAndFinish() {
        save()
        close(finished: true)
    }
}

struct BreathCircle: View {
    let color: Color
    let inSeconds: Double
    let outSeconds: Double
    @State private var expanded = false
    var body: some View {
        Circle()
            .fill(color.opacity(0.25))
            .overlay(Circle().stroke(color, lineWidth: 2))
            .frame(width: 200, height: 200)
            .scaleEffect(expanded ? 1 : 0.6)
            .task {
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: inSeconds)) { expanded = true }
                    try? await Task.sleep(for: .seconds(inSeconds))
                    withAnimation(.easeInOut(duration: outSeconds)) { expanded = false }
                    try? await Task.sleep(for: .seconds(outSeconds))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Progress bar with cue markers (filled = played, outlined = upcoming).
struct CueTimeline: View {
    let playback: ExperiencePlayback
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(playback.track.title).font(EFont.body(15, .semibold))
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: playback.parts.count > 1 ? 3 : 0) {
                        ForEach(playback.parts) { part in
                            Capsule().fill(playback.parts.count > 1 ? part.feeling.color.opacity(0.3) : EColor.line).frame(height: 4)
                        }
                    }
                    Capsule().fill(EColor.text).frame(width: w * playback.progress, height: 4)
                    ForEach(Array((playback.autoCues ? playback.track.cueMarkersS : []).enumerated()), id: \.offset) { i, s in
                        let played = Double(s) <= playback.position
                        let cueColor = playback.parts.count > 1 ? playback.feeling(forCue: i).color : color
                        Circle()
                            .fill(played ? cueColor : EColor.ground)
                            .overlay(Circle().stroke(cueColor, lineWidth: 2))
                            .frame(width: 12, height: 12)
                            .offset(x: w * CGFloat(Double(s) / playback.duration) - 6)
                    }
                }
            }
            .frame(height: 16)
            HStack {
                Text(timeString(playback.position)); Spacer()
                Text(playback.autoCues
                     ? "Cue \(min(playback.nextCueIndex + 1, playback.track.cueMarkersS.count)) of \(playback.track.cueMarkersS.count)"
                     : "\(playback.tapCount) \(playback.tapCount == 1 ? "tap" : "taps")"); Spacer()
                Text(timeString(playback.duration))
            }
            .font(EFont.body(12)).foregroundStyle(EColor.textMuted)
        }
    }
}

func timeString(_ s: Double) -> String {
    let t = max(0, Int(s))
    return "\(t / 60):\(String(format: "%02d", t % 60))"
}

// MARK: 2.4 First reminder — spread through the day (default) or at set times

struct FirstReminderView: View {
    let experienceID: UUID?
    @Environment(\.modelContext) private var context
    @Query private var experiences: [Experience]
    @Query private var profiles: [EmotionProfile]
    @State private var setTimes = false
    @State private var perDay = 3
    @State private var start = dateFromMinutes(9 * 60)
    @State private var end = dateFromMinutes(20 * 60)
    @State private var random = true
    @State private var checkIn = true
    @State private var times: [SetTime] = [
        SetTime(minutes: 7 * 60 + 30),
        SetTime(minutes: 13 * 60, days: SetTime.weekdays),
    ]

    private var experience: Experience? { experiences.first { $0.id == experienceID } }
    private var arc: [Feeling] { experience?.feelings ?? [profiles.first?.activeFeeling ?? .gratitude] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EOnboardingHeader(progress: nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(experience?.title ?? arc[0].name), through the day").font(EFont.display(28)).padding(.top, 14).padding(.bottom, 6)
                    Text("Your ring plays \(arc.map { $0.name.lowercased() }.joined(separator: ", then ")). Pause for a breath and see it as real.")
                        .font(EFont.body(15)).foregroundStyle(EColor.textSecondary).padding(.bottom, 16)
                    Picker("Reminder style", selection: $setTimes) {
                        Text("Spread through the day").tag(false)
                        Text("At set times").tag(true)
                    }
                    .pickerStyle(.segmented).padding(.bottom, 20)
                    if setTimes {
                        SetTimesEditor(times: $times)
                        InfoNote(icon: "info.circle", text: SetTimesEditor.iPhoneTimingNote).padding(.top, 14)
                        ToggleRow(title: "Quick check-in after", subtitle: "A notification to rate the moment", isOn: $checkIn)
                            .padding(.horizontal, 16).eCard().padding(.top, 12)
                    } else {
                        ReminderEditor(perDay: $perDay, start: $start, end: $end, random: $random, checkIn: $checkIn)
                        InfoNote(icon: "moon", text: "Quiet hours 21:00–08:00 are on. Change them in Reminders any time.").padding(.top, 16)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            Button("Save and finish") { finish(save: true) }.buttonStyle(PrimaryButtonStyle()).padding(.top, 12)
            Button("Later") { finish(save: false) }.buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func finish(save: Bool) {
        if save {
            if setTimes {
                for t in times {
                    let rule = ReminderRule(feeling: arc[0], perDay: 1)
                    rule.experienceID = experience?.id
                    rule.randomTimes = false
                    rule.fixedMinutes = [t.minutes]
                    rule.fixedDays = t.days
                    rule.enabled = t.on
                    rule.checkInAfter = checkIn
                    context.insert(rule)
                }
            } else {
                let rule = ReminderRule(feeling: arc[0], perDay: perDay)
                rule.experienceID = experience?.id
                rule.windowStartMinutes = minutes(start)
                rule.windowEndMinutes = minutes(end)
                rule.randomTimes = true   // spread = varied times inside the window
                rule.checkInAfter = checkIn
                context.insert(rule)
            }
        }
        let p = context.emotionProfile()
        p.onboardingCompleted = true
        try? context.save()
        ReminderScheduler.rebuild(context: context)
    }
}

func minutes(_ date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

func dateFromMinutes(_ m: Int) -> Date {
    Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
}

struct ReminderEditor: View {
    @Binding var perDay: Int
    @Binding var start: Date
    @Binding var end: Date
    @Binding var random: Bool
    @Binding var checkIn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("How often").padding(.bottom, 10)
            Picker("How often", selection: $perDay) {
                Text("2 a day").tag(2); Text("3 a day").tag(3); Text("5 a day").tag(5)
            }
            .pickerStyle(.segmented)
            SectionLabel("When").padding(.top, 22).padding(.bottom, 10)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Between").font(EFont.body(15, .semibold))
                        Text("Times vary each day").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                    }
                    Spacer()
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                    Text("–")
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
                }
                .frame(minHeight: 56)
                Divider().overlay(EColor.line)
                ToggleRow(title: "Quick check-in after", subtitle: "A notification to rate the moment", isOn: $checkIn)
            }
            .padding(.horizontal, 16).eCard()
        }
    }
}
