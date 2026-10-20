import Photos
import SwiftData
import SwiftUI
import UIKit

struct LibraryView: View {
    @Environment(EmotionRouter.self) private var router
    @State private var theme: MusicTheme = .abundance
    @Query(sort: \Experience.createdAt, order: .reverse) private var experiences: [Experience]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Experiences").font(EFont.display(28))
                    Spacer()
                    Button { router.push(.builder(nil)) } label: {
                        Label("New experience", systemImage: "plus").font(EFont.body(14, .bold)).foregroundStyle(EColor.onAccent)
                            .padding(.horizontal, 16).frame(height: 40).background(EColor.accent, in: Capsule())
                    }
                }
                .padding(.top, 8)
                // "My music" is coming soon: shown but not selectable yet.
                HStack(spacing: 4) {
                    Text("My experiences").font(EFont.body(14, .semibold))
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(EColor.cardRaised, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityAddTraits(.isSelected)
                    HStack(spacing: 6) {
                        Text("My music").font(EFont.body(14, .semibold))
                        Text("Soon").font(EFont.body(11, .bold)).foregroundStyle(EColor.onAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(EColor.textMuted, in: Capsule())
                    }
                    .foregroundStyle(EColor.textMuted)
                    .frame(maxWidth: .infinity).frame(height: 34)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("My music, coming soon")
                    .accessibilityAddTraits(.isStaticText)
                }
                .padding(3)
                .background(EColor.card, in: RoundedRectangle(cornerRadius: 11))
                mine
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Music library, shown again as "My music" once songs are ready.
    private var explore: some View {
        VStack(alignment: .leading, spacing: 16) {
            EFlowChips(items: MusicTheme.allCases) { t in
                Chip(title: t.name, dot: t.color, selected: t == theme, selectedColor: t.color) { theme = t }
            }
            SectionLabel("Feel-good tracks · \(theme.name)")
            ForEach(MusicTrack.catalog.filter { $0.theme == theme }) { track in
                Button {
                    let feeling = Feeling.allCases.first { MusicTrack.default(for: $0).theme == theme } ?? .gratitude
                    router.training = TrainingRequest(feeling: feeling, experienceID: nil)
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12).fill(theme.art).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(EFont.body(15, .semibold))
                            Text("\(theme.name) · \(track.durationLabel) · \(track.cueMarkersS.count) ring cues").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(10).eCard(radius: 18)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                Image(systemName: "music.note").font(.system(size: 24)).foregroundStyle(Color(hex: "#B892FF"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make a song for your feeling").font(EFont.body(15, .semibold))
                    Text("AI music generation · coming later").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#17131F"), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
    }

    @ViewBuilder private var mine: some View {
        if experiences.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("No visions yet").font(EFont.display(20))
                Text("Write down something you'd love to live, choose the feelings it brings, and your ring will bring it back to you.")
                    .font(EFont.body(14)).foregroundStyle(EColor.textSecondary)
                SectionLabel("Start from").padding(.top, 6)
                ForEach(VisionTemplate.all) { t in VisionTemplateRow(template: t, selected: false) { router.push(.newFromTemplate(t.id)) } }
            }
            .padding(20).eCard()
        } else {
            ForEach(experiences) { exp in
                ExperienceCard(experience: exp)
            }
        }
    }
}

struct ExperienceCard: View {
    let experience: Experience
    @Environment(EmotionRouter.self) private var router
    var body: some View {
        VStack(spacing: 0) {
            Button { router.experienceToPlay = experience } label: {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        SlideTile(experience: experience, index: i).frame(height: 96).clipped()
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(experience.title.isEmpty ? "Untitled vision" : experience.title).font(EFont.body(16, .bold))
                    Text("\(experience.arcLabel) · \(experience.imagesLabel)").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                }
                Spacer()
                Button { router.push(.builder(experience.id)) } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                    .accessibilityLabel("Edit").foregroundStyle(EColor.textSecondary)
                Button { router.experienceToPlay = experience } label: {
                    Image(systemName: "play.fill").foregroundStyle(EColor.ground).frame(width: 44, height: 44).background(experience.feeling.color, in: Circle())
                }
                .accessibilityLabel("Play \(experience.title)")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .eCard(radius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

/// Wrapping row of chips.
struct EFlowChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content
    var body: some View {
        FlowLayout(spacing: 8) { ForEach(items) { content($0) } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
    }
}

// MARK: Slideshow & device photos

/// Loads a device photo by its Photos identifier. Nothing is copied or uploaded.
@MainActor
final class PhotoLoader {
    static let shared = PhotoLoader()
    private var cache: [String: UIImage] = [:]

    func image(for identifier: String, size: CGSize) async -> UIImage? {
        if let hit = cache[identifier] { return hit }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined { _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let target = CGSize(width: size.width * 2, height: size.height * 2)
        let image: UIImage? = await withCheckedContinuation { cont in
            PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFill, options: options) { img, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded { cont.resume(returning: img) }
            }
        }
        if let image { cache[identifier] = image }
        return image
    }
}

struct SlideTile: View {
    let experience: Experience?
    let index: Int
    var fallback: Feeling = .gratitude

    var body: some View {
        let slides = experience?.slides ?? []
        if slides.isEmpty {
            ImagePlaceholder(color: Color.placeholderTones[(index * 3 + (Feeling.allCases.firstIndex(of: experience?.feeling ?? fallback) ?? 0)) % 8])
        } else {
            SlideImage(slide: slides[index % slides.count])
        }
    }
}

struct SlideshowView: View {
    let experience: Experience?
    let index: Int
    let fallback: Feeling
    /// Kept for call sites; slides carry no caption now that real images exist.
    var showLabel = true
    var body: some View {
        ZStack {
            SlideTile(experience: experience, index: index, fallback: fallback).id(index)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 1.2), value: index)
    }
}

// MARK: 3.3a Experience player

struct ExperiencePlayerView: View {
    let experience: Experience
    @Environment(EmotionServices.self) private var services
    @Environment(EmotionRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var playback: ExperiencePlayback?
    @State private var showVision = false
    @State private var immersive = false

    var body: some View {
        VStack(spacing: 0) {
            PlayerStage(experience: experience, index: playback?.slideIndex ?? 0, fallback: experience.feeling,
                        immersive: $immersive, cueFeeling: playback?.isInCue == true ? playback?.currentFeeling : nil) {
                HStack(spacing: 8) {
                    PlayerBarButton(icon: "xmark", label: "Close") { playback?.stop(); dismiss() }
                    Spacer()
                    if let p = playback, p.isInCue {
                        HStack(spacing: 8) {
                            Circle().strokeBorder(p.currentFeeling.color, lineWidth: 3).frame(width: 14, height: 14).shadow(color: p.currentFeeling.color, radius: 6)
                            Text("\(p.currentFeeling.name) touch").font(EFont.body(13, .semibold))
                        }
                        .padding(.horizontal, 12).frame(height: 34).background(EColor.ground.opacity(0.85), in: Capsule())
                    }
                    Spacer()
                    PlayerBarButton(icon: "arrow.up.left.and.arrow.down.right", label: "Full screen image") {
                        withAnimation(.easeInOut(duration: 0.3)) { immersive = true }
                    }
                    SlideActionsMenu(experience: experience, index: playback?.slideIndex ?? 0) { n in
                        playback?.slideCount = n == 0 ? 6 : n
                    }
                    Button { showVision = true } label: {
                        Label("Vision", systemImage: "list.bullet").font(EFont.body(14, .bold))
                            .padding(.horizontal, 16).frame(height: 44).background(EColor.ground.opacity(0.85), in: Capsule())
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4)
            }
            if !immersive, let p = playback {
                controls(p).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(EColor.text)
        .background(EColor.ground)
        .statusBarHidden(immersive)
        .persistentSystemOverlays(immersive ? .hidden : .automatic)
        .onAppear {
            let p = services.playback(for: experience)
            playback = p
            p.play()
            experience.lastPlayedAt = Date()
        }
        .onDisappear { playback?.stop() }
        .sheet(isPresented: $showVision) {
            VisionSheet(experience: experience).environment(router)
                .presentationDetents([.medium, .large])
                .presentationBackground(EColor.tabBar)
        }
    }

    private func controls(_ p: ExperiencePlayback) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(experience.title).font(EFont.display(22))
            Text("\(p.track.title) · now: \(p.currentFeeling.name)").font(EFont.body(13)).foregroundStyle(EColor.textSecondary).padding(.top, 2)
            if p.parts.count > 1 {
                HStack(spacing: 4) {
                    ForEach(p.parts) { part in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(part.feeling.color.opacity(0.25))
                                Capsule().fill(part.feeling.color).frame(width: geo.size.width * p.fraction(of: part))
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(.top, 12).accessibilityHidden(true)
            }
            ThinProgress(value: p.progress, color: EColor.text, height: 4).padding(.top, 16)
            HStack { Text(timeString(p.position)); Spacer(); Text(timeString(p.duration)) }.font(EFont.body(12)).foregroundStyle(EColor.textMuted).padding(.top, 4)
            HStack(spacing: 36) {
                Button { p.seek(by: -15) } label: { Image(systemName: "gobackward.15").font(.system(size: 22)).frame(width: 48, height: 48) }
                    .accessibilityLabel("Back 15 seconds")
                Button { p.toggle() } label: {
                    Image(systemName: p.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 26)).foregroundStyle(EColor.onAccent)
                        .frame(width: 72, height: 72).background(p.currentFeeling.color, in: Circle())
                }
                .accessibilityLabel(p.isPlaying ? "Pause" : "Play")
                Button { p.seek(by: 15) } label: { Image(systemName: "goforward.15").font(.system(size: 22)).frame(width: 48, height: 48) }
                    .accessibilityLabel("Forward 15 seconds")
            }
            .frame(maxWidth: .infinity).padding(.top, 10)
        }
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)
    }
}

struct VisionSheet: View {
    let experience: Experience
    @Environment(\.dismiss) private var dismiss
    @Environment(EmotionRouter.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(experience.feelings) { f in
                    HStack(spacing: 6) { Circle().fill(f.color).frame(width: 8, height: 8); Text(f.name).font(EFont.body(13, .semibold)) }
                        .padding(.horizontal, 10).frame(height: 30).background(f.ground, in: Capsule())
                }
            }
            .padding(.top, 24)
            Text(experience.title).font(EFont.display(26))
            ForEach(experience.visionPoints.filter { !$0.isEmpty }, id: \.self) { point in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle().fill(experience.feeling.color).frame(width: 7, height: 7)
                    Text(point).font(EFont.body(16))
                }
            }
            Spacer()
            HStack(spacing: 10) {
                Button("Edit") {
                    dismiss()
                    router.experienceToPlay = nil
                    router.tab = .library
                    router.libraryPath.append(ERoute.builder(experience.id))
                }
                .buttonStyle(SecondaryButtonStyle(height: 50))
                Button("Back to slideshow") { dismiss() }.buttonStyle(PrimaryButtonStyle(color: EColor.text, foreground: EColor.ground, height: 50))
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 24)
        .foregroundStyle(EColor.text)
    }
}

/// One starter vision with its suggested feeling arc.
struct VisionTemplateRow: View {
    let template: VisionTemplate
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12).fill(template.tile).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title).font(EFont.body(15, .bold))
                    HStack(spacing: 6) {
                        ForEach(Array(template.feelings.enumerated()), id: \.element) { i, f in
                            HStack(spacing: 5) {
                                Circle().fill(f.color).frame(width: 7, height: 7)
                                Text((i > 0 ? "→ " : "") + f.name).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14).frame(minHeight: 64)
            .background(EColor.cardRaised, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? EColor.accent : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
