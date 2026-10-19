import PhotosUI
import SwiftData
import SwiftUI

/// 3.4 Create experience — vision (title + points), feeling (+ its ring touch), music, images.
struct ExperienceBuilderView: View {
    let experienceID: UUID?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router

    @State private var title = ""
    @State private var points: [String] = ["", "", ""]
    @State private var feeling: Feeling = .gratitude
    @State private var track: MusicTrack = MusicTrack.default(for: .gratitude)
    @State private var imageRefs: [String] = []
    @State private var touch: TouchPattern = Feeling.gratitude.touch
    @State private var cueAuto = true
    @State private var loaded = false
    @State private var showTrackPicker = false
    @State private var showImages = false
    @State private var preview: ExperiencePlayback?

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
                Text("What it looks like — write each point as if it is already true").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.top, 16).padding(.bottom, 6)
                VStack(spacing: 8) {
                    ForEach(points.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            Circle().fill(feeling.color).frame(width: 8, height: 8)
                            TextField("Add a detail of your vision", text: $points[i], axis: .vertical).font(EFont.body(15))
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

                SectionLabel("2 · The feeling of having it").padding(.top, 28).padding(.bottom, 6)
                Text("Your ring will use this feeling's touch to bring the vision back to you.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.bottom, 10)
                FlowLayout(spacing: 8) {
                    ForEach(Feeling.allCases) { f in
                        Chip(title: f.name, dot: f.color, selected: f == feeling, selectedColor: f.color) {
                            let followsFeeling = touch.id.hasPrefix("feeling.")
                            feeling = f
                            if followsFeeling { touch = f.touch }
                            if track.theme == MusicTrack.default(for: feeling).theme || !loaded { track = MusicTrack.default(for: f) }
                        }
                    }
                }
                NavigationLink {
                    TouchPickerView(feeling: feeling, selection: $touch)
                } label: {
                    HStack(spacing: 12) {
                        TouchGlyph(pattern: touch, color: feeling.color, scale: 0.02).frame(width: 80, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(touch.id.hasPrefix("feeling.") ? "Ring touch · suggested" : "Ring touch").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                            Text(touch.name).font(EFont.body(15, .bold))
                        }
                        Spacer()
                        Text("Change").font(EFont.body(14, .semibold)).foregroundStyle(EColor.accent)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 60).eCard(radius: 16)
                }
                .buttonStyle(.plain).padding(.top, 12)

                SectionLabel("3 · Music & images").padding(.top, 28).padding(.bottom, 10)
                VStack(spacing: 8) {
                    row(title: "Music", value: "\(track.title) · \(track.durationLabel)", leading: AnyView(RoundedRectangle(cornerRadius: 10).fill(track.theme.art).frame(width: 40, height: 40))) { showTrackPicker = true }
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

                Button("Save and start training") {
                    let exp = save()
                    dismiss()
                    router.training = TrainingRequest(feeling: exp.feeling, experienceID: exp.id)
                }
                .buttonStyle(PrimaryButtonStyle()).padding(.top, 28)
                Button("Save for later") { _ = save(); dismiss() }
                    .buttonStyle(TextLinkButtonStyle()).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .emotionScreen()
        .navigationTitle(experienceID == nil ? "New experience" : "Edit experience")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Save") { _ = save(); dismiss() }.fontWeight(.bold) }
        }
        .onAppear(perform: load)
        .onDisappear { preview?.stop() }
        .sheet(isPresented: $showTrackPicker) { TrackPickerSheet(selected: $track) }
        .sheet(isPresented: $showImages) { ImagesPickerView(refs: $imageRefs, feeling: feeling) }
    }

    private var imagesLabel: String {
        let photos = imageRefs.filter { $0.hasPrefix("photo:") }.count
        if photos > 0 { return "\(photos) of your photos" }
        if let id = imageRefs.first(where: { $0.hasPrefix("app:") })?.dropFirst(4), let set = ImageSet.all.first(where: { $0.id == String(id) }) { return set.name }
        return "None yet"
    }

    private var previewCard: some View {
        let draft = draftExperience()
        return ZStack(alignment: .bottom) {
            SlideshowView(experience: draft, index: preview?.slideIndex ?? 0, fallback: feeling)
            HStack(spacing: 12) {
                Button {
                    if preview == nil { preview = ExperiencePlayback(track: track, touch: touch, haptics: services.haptics) }
                    preview?.toggle()
                } label: {
                    Image(systemName: preview?.isPlaying == true ? "pause.fill" : "play.fill").foregroundStyle(EColor.onAccent)
                        .frame(width: 44, height: 44).background(EColor.accent, in: Circle())
                }
                .accessibilityLabel(preview?.isPlaying == true ? "Pause preview" : "Play preview")
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Preview · music + slideshow").font(EFont.body(12, .bold)); Spacer(); Text("\(timeString(preview?.position ?? 0)) / \(track.durationLabel)").font(EFont.body(12)).foregroundStyle(EColor.textSecondary) }
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
        let e = Experience(title: title, points: points, feeling: feeling, trackID: track.id)
        e.imageRefs = imageRefs
        return e
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let id = experienceID,
              let e = try? context.fetch(FetchDescriptor<Experience>(predicate: #Predicate { $0.id == id })).first else {
            let f = context.emotionProfile().activeFeeling
            feeling = f; touch = f.touch; track = MusicTrack.default(for: f)
            return
        }
        title = e.title
        points = e.visionPoints.isEmpty ? [""] : e.visionPoints
        feeling = e.feeling
        track = e.track
        imageRefs = e.imageRefs
        touch = e.touch
        cueAuto = e.cueAuto
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
        e.feeling = feeling
        e.trackID = track.id
        e.imageRefs = imageRefs
        e.touch = touch
        e.cueAuto = cueAuto
        try? context.save()
        return e
    }
}

// MARK: 3.4a Images

struct ImagesPickerView: View {
    @Binding var refs: [String]
    let feeling: Feeling
    @Environment(\.dismiss) private var dismiss
    @State private var segment = 1
    @State private var pickerItems: [PhotosPickerItem] = []

    private var photoIDs: [String] { refs.compactMap { $0.hasPrefix("photo:") ? String($0.dropFirst(6)) : nil } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Source", selection: $segment) { Text("App images").tag(0); Text("Your photos").tag(1) }.pickerStyle(.segmented)
                if segment == 0 {
                    ScrollView {
                        Text("Curated sets that match each feeling").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ImageSet.all) { set in
                                let selected = refs.contains("app:\(set.id)")
                                Button { refs = ["app:\(set.id)"] } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                                            ForEach(0..<4, id: \.self) { i in (i % 3 == 0 ? set.feeling.ground : set.feeling.color.opacity(0.35)).frame(height: 46) }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text(set.name).font(EFont.body(14, .bold))
                                        Text("\(set.feeling.name) · \(set.count)").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                                    }
                                    .padding(8).eCard(radius: 16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? EColor.accent : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images, photoLibrary: .shared()) {
                            Label(photoIDs.isEmpty ? "Choose photos" : "Change photos (\(photoIDs.count) selected)", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        Text("Tap photos in the order you want them to appear.").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                                ForEach(Array(photoIDs.enumerated()), id: \.offset) { i, _ in
                                    ZStack(alignment: .topTrailing) {
                                        SlideTile(experience: previewExperience, index: i).aspectRatio(1, contentMode: .fill).clipShape(RoundedRectangle(cornerRadius: 6))
                                        Text("\(i + 1)").font(EFont.body(13, .bold)).foregroundStyle(EColor.onAccent).frame(width: 24, height: 24).background(EColor.accent, in: Circle()).padding(6)
                                    }
                                }
                            }
                        }
                        InfoNote(icon: "lock", text: "Your photos never leave this phone. We only remember which ones you picked.")
                    }
                }
                Spacer(minLength: 0)
                Button("Use these") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
            .emotionScreen()
            .navigationTitle("Images").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onChange(of: pickerItems) { _, items in
                let ids = items.compactMap(\.itemIdentifier)
                refs = ids.map { "photo:\($0)" }
            }
        }
    }

    private var previewExperience: Experience {
        let e = Experience(feeling: feeling)
        e.imageRefs = refs
        return e
    }
}
