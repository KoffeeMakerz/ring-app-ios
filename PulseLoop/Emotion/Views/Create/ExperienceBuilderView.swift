import PhotosUI
import UIKit
import SwiftData
import SwiftUI

/// 3.4 / 7.3 Create experience — vision (title + points), the ordered arc of feelings you'd feel
/// if it were real (each with its own ring touch), music and images.
struct ExperienceBuilderView: View {
    let experienceID: UUID?
    /// Prefill from a starter vision (onboarding / "New vision").
    var templateID: String? = nil
    /// Onboarding passes this to continue its own flow instead of dismissing.
    var onSaved: ((Experience, _ startNow: Bool) -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router

    @State private var title = ""
    @State private var points: [String] = ["", "", ""]
    @State private var arc: [Feeling] = [.joy, .gratitude]
    @State private var track: MusicTrack = MusicTrack.default(for: .joy)
    @State private var imageRefs: [String] = []
    @State private var cueAuto = true
    @State private var loaded = false
    @State private var showTrackPicker = false
    @State private var showImages = false
    @State private var preview: ExperiencePlayback?

    private var accent: Color { arc.first?.color ?? EColor.accent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                previewCard
                SectionLabel("1 · Your vision").padding(.top, 26).padding(.bottom, 10)
                Text("Name it").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                TextField("e.g. Our home by the sea", text: $title)
                    .font(EFont.display(18)).padding(.horizontal, 16).frame(minHeight: 52)
                    .background(EColor.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(EColor.line, lineWidth: 1.5))
                    .padding(.top, 6)
                Text("What it looks like — write it as if it's already true").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.top, 16).padding(.bottom, 6)
                VStack(spacing: 8) {
                    ForEach(points.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            Circle().fill(accent).frame(width: 8, height: 8)
                            TextField("Add a detail of your vision", text: $points[i]).font(EFont.body(15))
                                .submitLabel(i == points.count - 1 ? .done : .next)
                            Button { points.remove(at: i) } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 40, height: 40) }
                                .foregroundStyle(EColor.textMuted).accessibilityLabel("Remove point \(i + 1)")
                        }
                        .padding(.leading, 14).frame(minHeight: 52).eCard(radius: 14)
                    }
                    Button { points.append("") } label: {
                        Label("Add a point", systemImage: "plus").font(EFont.body(14, .semibold)).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 14)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                }

                SectionLabel("2 · What you feel when it's real").padding(.top, 28).padding(.bottom, 6)
                Text("Pick 1–3 feelings in the order they come. Each gets its own part of the song and its own ring touch.")
                    .font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.bottom, 12)
                VStack(spacing: 8) {
                    ForEach(Array(arc.enumerated()), id: \.element) { i, f in arcRow(i, f) }
                }
                if arc.count < Feeling.maxPerExperience {
                    Text(arc.isEmpty ? "Pick a feeling" : "Add a feeling").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.top, 14).padding(.bottom, 8)
                    FlowLayout(spacing: 8) {
                        ForEach(Feeling.unlockOrder.filter { !arc.contains($0) }) { f in
                            Chip(title: f.name, dot: f.color, selected: false, selectedColor: f.color) { setArc(arc + [f]) }
                        }
                    }
                }
                sequenceCard.padding(.top, 14)

                SectionLabel("3 · Music & images").padding(.top, 28).padding(.bottom, 10)
                VStack(spacing: 8) {
                    Button { showTrackPicker = true } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10).fill(track.theme.art).frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Music").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                                    Text("\(track.title) · \(track.durationLabel)").font(EFont.body(15, .bold))
                                }
                                Spacer()
                                Text("Change").font(EFont.body(14, .semibold)).foregroundStyle(EColor.accent)
                            }
                            if !arc.isEmpty { SongPartsBar(feelings: arc, durationS: track.durationS) }
                        }
                        .padding(14).eCard(radius: 16)
                    }
                    .buttonStyle(.plain)
                    row(title: "Images (optional)", value: imagesLabel, leading: nil) { showImages = true }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ring touches during the song").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                            Text(cueAuto ? "\(track.cueMarkersS.count) times, on the chorus" : "You tap while it plays").font(EFont.body(15, .bold))
                        }
                        Spacer()
                        Picker("Cue mode", selection: $cueAuto) { Text("Auto").tag(true); Text("Tap").tag(false) }
                            .pickerStyle(.segmented).frame(width: 120)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 60).eCard(radius: 16)
                }

                Button("Save and live it") {
                    let exp = save()
                    finish(exp, startNow: true)
                }
                .buttonStyle(PrimaryButtonStyle()).padding(.top, 28)
                .disabled(arc.isEmpty)
                Button("Save for later") { finish(save(), startNow: false) }
                    .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
                    .disabled(arc.isEmpty)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .emotionScreen()
        .navigationTitle(experienceID == nil ? "New experience" : "Edit experience")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Save") { finish(save(), startNow: false) }.fontWeight(.bold).disabled(arc.isEmpty) }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: load)
        .onDisappear { preview?.stop() }
        .onChange(of: track) { _, _ in preview?.stop(); preview = nil }
        .sheet(isPresented: $showTrackPicker) { TrackPickerSheet(selected: $track) }
        .sheet(isPresented: $showImages) { ImagesPickerView(refs: $imageRefs, feelings: arc.isEmpty ? [.gratitude] : arc) }
    }

    // MARK: Arc

    private func setArc(_ next: [Feeling]) {
        let wasDefaultTrack = arc.first.map { MusicTrack.default(for: $0) == track } ?? true
        arc = Array(next.prefix(Feeling.maxPerExperience))
        if wasDefaultTrack, let first = arc.first { track = MusicTrack.default(for: first) }
        preview?.stop(); preview = nil
    }

    private func arcRow(_ i: Int, _ f: Feeling) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(i + 1)").font(EFont.body(13, .bold)).foregroundStyle(EColor.ground)
                    .frame(width: 26, height: 26).background(f.color, in: Circle())
                Text(f.name).font(EFont.body(16, .bold))
                Spacer()
                Button { var n = arc; n.swapAt(i, i - 1); setArc(n) } label: { Image(systemName: "chevron.up").frame(width: 40, height: 40) }
                    .disabled(i == 0).opacity(i == 0 ? 0.3 : 1).accessibilityLabel("Move \(f.name) earlier")
                Button { var n = arc; n.swapAt(i, i + 1); setArc(n) } label: { Image(systemName: "chevron.down").frame(width: 40, height: 40) }
                    .disabled(i == arc.count - 1).opacity(i == arc.count - 1 ? 0.3 : 1).accessibilityLabel("Move \(f.name) later")
                Button { setArc(arc.filter { $0 != f }) } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 40, height: 40) }
                    .accessibilityLabel("Remove \(f.name)")
            }
            .foregroundStyle(EColor.textSecondary)
            Text("“\(f.experiencePrompt)”").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.trailing, 8)
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 12)
        .eCard(radius: 18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(f.color, lineWidth: 1.5))
    }

    private var sequenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Ring touch sequence")
            if arc.isEmpty {
                Text("Pick a feeling to hear its touch.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(arc.enumerated()), id: \.element) { i, f in
                        HStack(spacing: 8) {
                            if i > 0 { Text("\(Feeling.sequenceGapMs / 1000) s").font(EFont.body(12, .semibold)).foregroundStyle(EColor.textMuted) }
                            TouchGlyph(pattern: f.touch, color: f.color, scale: 0.02, height: 8, maxWidth: 70)
                                .padding(.horizontal, 8).frame(height: 24).background(EColor.cardRaised, in: Capsule())
                        }
                    }
                }
                .accessibilityElement().accessibilityLabel(arc.map(\.name).joined(separator: ", then ") + " touch")
                HStack(spacing: 12) {
                    Text("Each feeling's own touch, in order, at least \(Feeling.sequenceGapMs / 1000) s apart. Reminders for this vision play the same.")
                        .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    Spacer(minLength: 0)
                    Button("Feel it") { services.haptics.play(Feeling.sequence(arc)) }
                        .font(EFont.body(13, .bold)).foregroundStyle(EColor.onAccent)
                        .padding(.horizontal, 14).frame(height: 40).background(accent, in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#17131F"), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(EColor.line))
    }

    private var imagesLabel: String { SlideRef.label(imageRefs) }

    private var previewCard: some View {
        let draft = draftExperience()
        return ZStack(alignment: .bottom) {
            SlideshowView(experience: draft, index: preview?.slideIndex ?? 0, fallback: arc.first ?? .gratitude)
            HStack(spacing: 12) {
                Button {
                    if preview == nil { preview = ExperiencePlayback(track: track, feelings: arc, haptics: services.haptics) }
                    preview?.toggle()
                } label: {
                    Image(systemName: preview?.isPlaying == true ? "pause.fill" : "play.fill").foregroundStyle(EColor.onAccent)
                        .frame(width: 44, height: 44).background(EColor.accent, in: Circle())
                }
                .accessibilityLabel(preview?.isPlaying == true ? "Pause preview" : "Play preview")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(preview.map { "Preview · \($0.currentFeeling.name)" } ?? "Preview · music + slideshow").font(EFont.body(12, .bold))
                        Spacer()
                        Text("\(timeString(preview?.position ?? 0)) / \(track.durationLabel)").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                    }
                    ThinProgress(value: preview?.progress ?? 0, color: EColor.text, height: 4)
                }
            }
            .padding(12)
            .background(EColor.ground.opacity(0.92))
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.top, 8)
    }

    private func row(title: String, value: String, leading: AnyView?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let leading { leading }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                    Text(value).font(EFont.body(15, .bold))
                }
                Spacer()
                Text("Change").font(EFont.body(14, .semibold)).foregroundStyle(EColor.accent)
            }
            .padding(.horizontal, 14).frame(minHeight: 60).eCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    /// A transient, unsaved experience used for the preview tiles.
    private func draftExperience() -> Experience {
        let e = Experience(title: title, points: points, feelings: arc.isEmpty ? [.gratitude] : arc, trackID: track.id)
        e.imageRefs = imageRefs
        return e
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id = experienceID,
           let e = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first {
            title = e.title
            points = e.visionPoints.isEmpty ? [""] : e.visionPoints
            arc = e.feelings
            track = e.track
            imageRefs = SlideRef.normalized(e.imageRefs)
            cueAuto = e.cueAuto
        } else if let t = VisionTemplate.all.first(where: { $0.id == templateID }) {
            title = t.title
            points = t.points
            arc = t.feelings
            track = t.track
            // Start the slideshow with images that fit the template; the user can add or remove any.
            let starter = ["home": "home", "money": "abundance", "love": "together", "business": "growth", "health": "shores"][t.id]
            if let set = ImageSet.all.first(where: { $0.id == starter }) { imageRefs = set.imageNames.map { "img:\($0)" } }
        } else {
            arc = [.joy, .gratitude]
            track = MusicTrack.default(for: .joy)
        }
    }

    private func finish(_ exp: Experience, startNow: Bool) {
        preview?.stop()
        if let onSaved { onSaved(exp, startNow); return }
        dismiss()
        if startNow { router.training = TrainingRequest(feeling: exp.feeling, experienceID: exp.id) }
    }

    @discardableResult
    private func save() -> Experience {
        let e: Experience
        if let id = experienceID, let existing = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first {
            e = existing
        } else {
            e = Experience()
            context.insert(e)
        }
        e.title = title.trimmingCharacters(in: .whitespaces).isEmpty ? "My vision" : title
        e.visionPoints = points.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        e.feelings = arc.isEmpty ? [.gratitude] : arc
        e.customTouchData = nil   // v2: each feeling plays its own touch
        e.trackID = track.id
        e.imageRefs = imageRefs
        e.cueAuto = cueAuto
        try? context.save()
        ExperienceImageStore.prune(context)
        return e
    }
}

/// The song split into one coloured part per feeling, with time ranges.
struct SongPartsBar: View {
    let feelings: [Feeling]
    let durationS: Int
    var body: some View {
        let n = max(1, feelings.count)
        VStack(alignment: .leading, spacing: 6) {
            Text("The song in parts").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            HStack(spacing: 3) {
                ForEach(feelings) { f in
                    RoundedRectangle(cornerRadius: 6).fill(f.color.opacity(0.22)).frame(height: 24)
                        .overlay(Circle().fill(f.color).frame(width: 6, height: 6))
                }
            }
            HStack(spacing: 3) {
                ForEach(Array(feelings.enumerated()), id: \.element) { i, f in
                    let a = durationS * i / n, b = durationS * (i + 1) / n
                    (Text(f.name).bold().foregroundColor(EColor.text) + Text(" \(timeString(Double(a)))–\(timeString(Double(b)))"))
                        .font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: 3.4a Images

/// Build the slideshow one image at a time: tap app images to add or remove them, add your own photos
/// (appended, never replacing), drag thumbnails to reorder.
struct ImagesPickerView: View {
    @Binding var refs: [String]
    let feelings: [Feeling]
    @Environment(\.dismiss) private var dismiss
    @State private var segment = 0
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importing = 0
    @State private var failed = 0

    private var isFull: Bool { refs.count >= SlideRef.maxCount }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                selectionStrip
                Picker("Source", selection: $segment) { Text("App images").tag(0); Text("Your photos").tag(1) }.pickerStyle(.segmented)
                if segment == 0 { appImages } else { yourPhotos }
                Button(refs.isEmpty ? "Done" : "Use \(refs.count) image\(refs.count == 1 ? "" : "s")") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .emotionScreen()
            .navigationTitle("Images").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if !refs.isEmpty { ToolbarItem(placement: .primaryAction) { Button("Clear") { refs = [] } } }
            }
            .onAppear { refs = SlideRef.normalized(refs) }
            .onChange(of: pickerItems) { _, items in importPhotos(items) }
        }
    }

    // MARK: Current slideshow

    private var selectionStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your slideshow").font(EFont.body(15, .bold))
                Spacer()
                Text("\(refs.count) of \(SlideRef.maxCount)").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
            }
            if refs.isEmpty {
                Text("Nothing yet. Tap images below to add them one by one.")
                    .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(EColor.line, style: StrokeStyle(lineWidth: 1.5, dash: [5])))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(refs.enumerated()), id: \.element) { i, ref in
                                if let slide = SlideRef(ref: ref) { thumb(slide, ref: ref, number: i + 1).id(ref) }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: refs.count) { old, new in
                        if new > old, let last = refs.last { withAnimation { proxy.scrollTo(last, anchor: .trailing) } }
                    }
                }
                .frame(height: 80)
                Text("Drag to reorder · hold for more").font(EFont.body(12)).foregroundStyle(EColor.textMuted)
            }
        }
    }

    private func thumb(_ slide: SlideRef, ref: String, number: Int) -> some View {
        SlideImage(slide: slide)
            .frame(width: 66, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomLeading) {
                Text("\(number)").font(EFont.body(11, .bold)).foregroundStyle(EColor.onAccent)
                    .frame(minWidth: 18, minHeight: 18).background(EColor.accent, in: Circle()).padding(4)
            }
            .overlay(alignment: .topTrailing) {
                Button { remove(ref) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(.black.opacity(0.65), in: Circle())
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .accessibilityLabel("Remove image \(number)")
            }
            .draggable(ref)
            .dropDestination(for: String.self) { items, _ in move(items.first, onto: ref) }
            .contextMenu {
                Button("Move earlier", systemImage: "arrow.left") { step(ref, by: -1) }.disabled(number == 1)
                Button("Move later", systemImage: "arrow.right") { step(ref, by: 1) }.disabled(number == refs.count)
                Button("Remove", systemImage: "trash", role: .destructive) { remove(ref) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Image \(number) of \(refs.count)")
    }

    // MARK: App images

    private var appImages: some View {
        let sets = ImageSet.ordered(for: feelings)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if !sets.suggested.isEmpty {
                    sectionHeader("Suggested for \(feelings.map(\.name).joined(separator: " → "))")
                    ForEach(sets.suggested) { setBlock($0) }
                }
                sectionHeader(sets.suggested.isEmpty ? "All images" : "More images")
                ForEach(sets.more) { setBlock($0) }
            }
            .padding(.bottom, 8)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased()).font(EFont.body(12, .bold)).tracking(1).foregroundStyle(EColor.textMuted)
    }

    private func setBlock(_ set: ImageSet) -> some View {
        let all = set.imageNames.map { "img:\($0)" }
        let allIn = all.allSatisfy { refs.contains($0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(set.name).font(EFont.body(15, .bold))
                Circle().fill(set.feeling.color).frame(width: 7, height: 7).accessibilityHidden(true)
                Text(set.feeling.name).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                Spacer()
                Button(allIn ? "Remove all" : "Add all") {
                    if allIn { refs.removeAll { all.contains($0) } }
                    else { for r in all where !refs.contains(r) && !isFull { refs.append(r) } }
                }
                .font(EFont.body(13, .semibold)).foregroundStyle(EColor.accent)
                .disabled(!allIn && isFull)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Array(set.imageNames.enumerated()), id: \.element) { n, name in
                    let ref = "img:\(name)"
                    let pos = refs.firstIndex(of: ref)
                    Button { toggle(ref) } label: {
                        Color.clear.frame(height: 100)
                            .overlay(Image(name).resizable().scaledToFill())
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(pos != nil ? EColor.accent : .clear, lineWidth: 2.5))
                            .overlay(alignment: .topTrailing) {
                                Group {
                                    if let pos {
                                        Text("\(pos + 1)").font(EFont.body(12, .bold)).foregroundStyle(EColor.onAccent)
                                            .frame(width: 24, height: 24).background(EColor.accent, in: Circle())
                                    } else {
                                        Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 24, height: 24).background(.black.opacity(0.55), in: Circle())
                                    }
                                }
                                .padding(6)
                            }
                            .opacity(pos == nil && isFull ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(set.name), image \(n + 1)")
                    .accessibilityValue(pos.map { "In slideshow, number \($0 + 1)" } ?? "Not added")
                    .accessibilityHint(pos == nil ? "Adds it to the end" : "Removes it")
                }
            }
        }
    }

    // MARK: Your photos

    private var yourPhotos: some View {
        let own = refs.compactMap(SlideRef.init(ref:)).filter(\.isOwnPhoto).count
        return VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, SlideRef.maxCount - refs.count), selectionBehavior: .ordered, matching: .images) {
                Label(own == 0 ? "Add photos" : "Add more photos", systemImage: "plus")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isFull || importing > 0)
            if importing > 0 {
                HStack(spacing: 10) { ProgressView(); Text("Adding \(importing) photo\(importing == 1 ? "" : "s")…").font(EFont.body(14)) }
            }
            if failed > 0 {
                Text("\(failed) photo\(failed == 1 ? "" : "s") couldn't be added.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            }
            if isFull {
                Text("Your slideshow is full (\(SlideRef.maxCount)). Remove one to add another.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            }
            Text(own == 0 ? "Pick one or several. They go to the end of your slideshow, and you can add more any time."
                          : "\(own) of your photos in the slideshow. New ones go to the end.")
                .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
            InfoNote(icon: "lock", text: "We keep a private copy on this phone, so the slideshow still works if you delete the original. Nothing is uploaded.")
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: Editing

    private func toggle(_ ref: String) {
        if let i = refs.firstIndex(of: ref) { refs.remove(at: i) }
        else if !isFull { refs.append(ref) }
    }

    private func remove(_ ref: String) {
        withAnimation { refs.removeAll { $0 == ref } }
    }

    private func step(_ ref: String, by delta: Int) {
        guard let i = refs.firstIndex(of: ref) else { return }
        let j = i + delta
        guard refs.indices.contains(j) else { return }
        withAnimation { refs.swapAt(i, j) }
    }

    /// Drop `dragged` onto `target`: moving forward lands after it, moving back lands before it.
    private func move(_ dragged: String?, onto target: String) -> Bool {
        guard let dragged, dragged != target, let from = refs.firstIndex(of: dragged), let targetIndex = refs.firstIndex(of: target) else { return false }
        withAnimation {
            refs.remove(at: from)
            let to = refs.firstIndex(of: target) ?? refs.endIndex
            refs.insert(dragged, at: from < targetIndex ? min(to + 1, refs.endIndex) : to)
        }
        return true
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        pickerItems = []
        failed = 0
        importing += items.count
        Task {
            for item in items {
                var name: String?
                if let data = try? await item.loadTransferable(type: Data.self) {
                    name = await Task.detached(priority: .userInitiated) { ExperienceImageStore.save(data) }.value
                }
                importing -= 1
                if let name, refs.count < SlideRef.maxCount { refs.append("file:\(name)") } else { failed += 1 }
            }
        }
    }
}
