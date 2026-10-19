import SwiftData
import SwiftUI

/// 3.4b Choose a ring touch — predefined touches first; creating your own is optional.
struct TouchPickerView: View {
    let feeling: Feeling
    @Binding var selection: TouchPattern
    @Environment(EmotionServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomTouch.createdAt, order: .reverse) private var custom: [CustomTouch]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick how your ring feels during this experience. Tap play to feel one first.")
                    .font(EFont.body(14)).foregroundStyle(EColor.textSecondary).padding(.bottom, 6)
                SectionLabel("Feeling touches")
                ForEach([feeling] + Feeling.allCases.filter { $0 != feeling }) { f in
                    touchRow(f.touch, color: f.color, note: f == feeling ? "Suggested for this experience" : f.rhythmDescription)
                }
                SectionLabel("Simple alerts").padding(.top, 12)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(TouchBlock.touches) { block in
                        let p = block.pattern
                        Button { selection = p; services.haptics.play(p) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                TouchGlyph(pattern: p, color: EColor.textSecondary, scale: 0.03)
                                Text(block.name).font(EFont.body(13, .bold))
                            }
                            .padding(12).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading).eCard(radius: 14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selection.id == p.id ? EColor.accent : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !custom.isEmpty {
                    SectionLabel("My touches").padding(.top, 12)
                    ForEach(custom) { c in touchRow(c.pattern, color: feeling.color, note: String(format: "%.1f s", Double(c.pattern.totalMs) / 1000)) }
                }
                NavigationLink {
                    TouchComposerView(feeling: feeling) { new in selection = new }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus").foregroundStyle(EColor.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create your own touch").font(EFont.body(14, .semibold))
                            Text("Optional · combine alerts into up to 8 s").font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(EColor.textMuted)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 56)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                .buttonStyle(.plain).padding(.top, 12)
            }
            .padding(.horizontal, 20).padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Circle().strokeBorder(services.haptics.isPlaying ? EColor.accent : Color(hex: "#4A4160"), lineWidth: 5).frame(width: 28, height: 28)
                    .shadow(color: services.haptics.isPlaying ? EColor.accent : .clear, radius: 8)
                Text(services.haptics.isPlaying ? "Playing on your ring" : (services.haptics.isRingConnected ? "Ring connected · tap play to feel" : "Ring not connected"))
                    .font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                Spacer()
                Button("Use \(selection.name.replacingOccurrences(of: " touch", with: ""))") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle(height: 48)).frame(width: 170)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(EColor.tabBar)
        }
        .emotionScreen()
        .navigationTitle("Ring touch").navigationBarTitleDisplayMode(.inline)
    }

    private func touchRow(_ pattern: TouchPattern, color: Color, note: String) -> some View {
        HStack(spacing: 12) {
            Button { selection = pattern } label: {
                HStack(spacing: 12) {
                    TouchGlyph(pattern: pattern, color: color, scale: 0.02).frame(width: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pattern.name).font(EFont.body(15, .bold))
                        Text(note).font(EFont.body(12)).foregroundStyle(EColor.textSecondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection.id == pattern.id ? .isSelected : [])
            Button { services.haptics.play(pattern) } label: {
                Image(systemName: "play.fill").frame(width: 44, height: 44).background(EColor.cardRaised, in: Circle())
            }
            .accessibilityLabel("Feel \(pattern.name) on ring")
            .foregroundStyle(EColor.text)
        }
        .padding(.leading, 14).padding(.trailing, 8).frame(minHeight: 58).eCard(radius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selection.id == pattern.id ? color : .clear, lineWidth: 1.5))
    }
}

/// 3.4c Create your own touch (optional block composer, max 8 s).
struct TouchComposerView: View {
    let feeling: Feeling
    var onSave: (TouchPattern) -> Void
    @Environment(EmotionServices.self) private var services
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var blocks: [TouchBlock] = [.doubleTap, .shortRest, .tap]
    @State private var name = "My touch"

    private var total: Int { TouchBlock.totalMs(blocks) }
    private var pattern: TouchPattern { TouchBlock.compose(blocks, name: name) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("Start from").font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach([Feeling.gratitude, .love, .joy, .calm]) { f in
                                Button(f.name) { blocks = f.blocks }.font(EFont.body(13, .semibold)).foregroundStyle(EColor.text)
                                    .padding(.horizontal, 12).frame(height: 34).background(EColor.card, in: Capsule())
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Circle().strokeBorder(services.haptics.isPlaying ? feeling.color : Color(hex: "#3A334D"), lineWidth: 6).frame(width: 40, height: 40)
                            .shadow(color: services.haptics.isPlaying ? feeling.color : .clear, radius: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Name", text: $name).font(EFont.display(19))
                            Text(String(format: "%.1f s of 8 s", Double(total) / 1000)).font(EFont.body(13)).foregroundStyle(EColor.textSecondary)
                        }
                        Button("Clear") { blocks = [] }.font(EFont.body(13, .semibold)).foregroundStyle(EColor.textSecondary)
                    }
                    PatternTrack(pattern: pattern, color: feeling.color)
                    FlowLayout(spacing: 6) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { i, b in
                            Button { blocks.remove(at: i) } label: {
                                HStack(spacing: 6) { Text(b.name).font(EFont.body(13, .semibold)); Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(EColor.textSecondary) }
                                    .padding(.horizontal, 12).frame(height: 32)
                                    .background(b.isRest ? Color.clear : EColor.cardRaised, in: Capsule())
                                    .overlay(Capsule().stroke(b.isRest ? Color(hex: "#4A4160") : EColor.line, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain).accessibilityLabel("Remove \(b.name)")
                        }
                    }
                    if blocks.isEmpty { Text("Tap a block below to start your touch.").font(EFont.body(13)).foregroundStyle(EColor.textMuted) }
                    Button { services.haptics.play(pattern) } label: { Label("Feel it on your ring", systemImage: "play.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: feeling.color, height: 48)).disabled(blocks.isEmpty)
                }
                .padding(16).eCard(radius: 24)

                SectionLabel("Add a touch").padding(.top, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(TouchBlock.touches) { b in
                        let fits = TouchBlock.totalMs(blocks + [b]) <= TouchPattern.maxDurationMs
                        Button { if fits { blocks.append(b) } } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                TouchGlyph(pattern: b.pattern, color: feeling.color, scale: 0.034)
                                Text(b.name).font(EFont.body(14, .bold))
                                Text(b.hint).font(EFont.body(11)).foregroundStyle(EColor.textSecondary)
                            }
                            .padding(12).frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).eCard(radius: 16)
                        }
                        .buttonStyle(.plain).disabled(!fits).opacity(fits ? 1 : 0.35)
                    }
                }
                SectionLabel("Add space")
                HStack(spacing: 8) {
                    ForEach(TouchBlock.rests) { b in
                        let fits = !blocks.isEmpty && TouchBlock.totalMs(blocks + [b]) <= TouchPattern.maxDurationMs
                        Button(b.name) { if fits { blocks.append(b) } }
                            .font(EFont.body(14, .semibold)).foregroundStyle(EColor.text)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "#4A4160"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                            .disabled(!fits).opacity(fits ? 1 : 0.35)
                    }
                }
                Text("Up to 8 seconds. A small gap is added between touches so each one is felt clearly.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
        .emotionScreen()
        .navigationTitle("Create your own touch").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let c = CustomTouch(name: name, blocks: blocks)
                    context.insert(c)
                    try? context.save()
                    onSave(c.pattern)
                    dismiss()
                }
                .fontWeight(.bold).disabled(blocks.isEmpty)
            }
        }
    }
}

/// The 8-second track with on-segments drawn to scale.
struct PatternTrack: View {
    let pattern: TouchPattern
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12).fill(EColor.ground)
                    HStack(spacing: 0) { ForEach(0..<8, id: \.self) { _ in Rectangle().fill(Color(hex: "#1E1A29")).frame(width: 1).frame(maxWidth: .infinity, alignment: .leading) } }
                    ForEach(Array(pattern.pulses.enumerated()), id: \.offset) { _, p in
                        Capsule().fill(color)
                            .frame(width: max(4, w * CGFloat(p.length) / 8000), height: 28)
                            .offset(x: w * CGFloat(p.start) / 8000)
                    }
                }
            }
            .frame(height: 52)
            HStack { Text("0 s"); Spacer(); Text("4 s"); Spacer(); Text("8 s") }.font(EFont.body(11)).foregroundStyle(EColor.textMuted)
        }
        .accessibilityElement().accessibilityLabel("Touch of \(String(format: "%.1f", Double(pattern.totalMs) / 1000)) seconds")
    }
}
