import SwiftUI

/// Design tokens for the emotion app (screen designs v1). Dark, night-sky ground with one warm
/// accent; every feeling carries its own colour.
enum EColor {
    static let ground = Color(hex: "#0E0B16")
    static let card = Color(hex: "#1A1625")
    static let cardRaised = Color(hex: "#241F31")
    static let line = Color(hex: "#2E2840")
    static let tabBar = Color(hex: "#14111C")
    static let text = Color(hex: "#F4F0FA")
    static let textSecondary = Color(hex: "#ABA3BA")
    static let textMuted = Color(hex: "#8A8299")
    static let accent = Color(hex: "#F2B45A")
    static let onAccent = Color(hex: "#1A1206")
    static let warmGround = Color(hex: "#2A1E10")
    static let calmGround = Color(hex: "#0B1220")
    static let calmCard = Color(hex: "#121C2E")
    static let success = Color(hex: "#6FD6A1")
    static let warning = Color(hex: "#FFB86B")
    static let danger = Color(hex: "#FF4D6D")
    static let debug = Color(hex: "#F5D76E")
}

enum EFont {
    /// Display face. The designs use Bricolage Grotesque; until the font files are bundled we use the
    /// system rounded face at the same weights.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, design: .monospaced) }
    static let label = Font.system(size: 12, weight: .bold)
}

// MARK: - Building blocks

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(EFont.label)
            .tracking(1.2)
            .foregroundStyle(EColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = EColor.accent
    var foreground: Color = EColor.onAccent
    var height: CGFloat = 56
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EFont.body(17, .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 48
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EFont.body(15, .semibold))
            .foregroundStyle(EColor.text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(EColor.cardRaised, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct TextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EFont.body(15, .semibold))
            .foregroundStyle(EColor.accent)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Chip: View {
    let title: String
    var dot: Color? = nil
    var selected: Bool = false
    var selectedColor: Color = EColor.accent
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
                Text(title).font(EFont.body(14, .semibold))
            }
            .foregroundStyle(EColor.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(selected ? EColor.cardRaised : EColor.card, in: Capsule())
            .overlay(Capsule().stroke(selected ? selectedColor : EColor.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct CardBackground: ViewModifier {
    var color: Color = EColor.card
    var radius: CGFloat = 20
    func body(content: Content) -> some View {
        content.background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func eCard(_ color: Color = EColor.card, radius: CGFloat = 20) -> some View {
        modifier(CardBackground(color: color, radius: radius))
    }
    /// Full-screen dark ground used by every emotion screen.
    func emotionScreen(_ ground: Color = EColor.ground) -> some View {
        background(ground.ignoresSafeArea())
            .foregroundStyle(EColor.text)
            .toolbarBackground(ground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// Segmented progress used at the top of onboarding.
struct StepProgress: View {
    let total: Int
    let current: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule().fill(i < current ? EColor.accent : EColor.line).frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

/// Simple horizontal progress bar.
struct ThinProgress: View {
    let value: Double
    var color: Color = EColor.accent
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(EColor.line)
                Capsule().fill(color).frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// A short rhythm picture of a touch pattern: coloured pills for motor-on, gaps for motor-off.
struct TouchGlyph: View {
    let pattern: TouchPattern
    var color: Color
    var scale: CGFloat = 0.034
    var height: CGFloat = 10
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(pattern.durationsMs.enumerated()), id: \.offset) { index, ms in
                let on = pattern.isOn(segment: index)
                Capsule()
                    .fill(on ? color : .clear)
                    .frame(width: max(4, CGFloat(ms) * scale), height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Placeholder used where real artwork / photos will go.
struct ImagePlaceholder: View {
    let color: Color
    var label: String? = nil
    var body: some View {
        ZStack {
            color
            if let label {
                Text(label.uppercased())
                    .font(EFont.body(11, .medium))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "#C9AE86"))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

extension Color {
    /// Shared tones for image placeholders, indexed deterministically.
    static let placeholderTones: [Color] = ["#3A2A16", "#4A3418", "#2D2245", "#1C2B40", "#3F1C28", "#1E3A2C", "#3D3418", "#28203A"].map { Color(hex: $0) }
}
