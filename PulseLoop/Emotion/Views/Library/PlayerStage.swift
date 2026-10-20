import SwiftUI

/// The slideshow area of a player. It fills the space above the controls, so nothing covers the
/// image but a thin top bar. Tap the image (or the expand button) for full screen; tap again to
/// bring the controls back. Music and ring touches keep playing either way.
struct PlayerStage<TopBar: View>: View {
    let experience: Experience?
    let index: Int
    let fallback: Feeling
    @Binding var immersive: Bool
    /// Set while the ring is playing a touch, so full screen still shows which feeling it is.
    var cueFeeling: Feeling? = nil
    @ViewBuilder var topBar: () -> TopBar
    @State private var showHint = false

    var body: some View {
        ZStack(alignment: .top) {
            SlideshowView(experience: experience, index: index, fallback: fallback, showLabel: false)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: immersive ? 0 : 24, bottomTrailingRadius: immersive ? 0 : 24))
                .ignoresSafeArea(edges: immersive ? .all : .top)
                .contentShape(Rectangle())
                .onTapGesture { toggle() }
                .accessibilityElement()
                .accessibilityLabel(immersive ? "Image, full screen" : "Image")
                .accessibilityHint(immersive ? "Shows the controls" : "Shows the image full screen")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { toggle() }

            if immersive {
                if let f = cueFeeling {
                    HStack(spacing: 8) {
                        Circle().strokeBorder(f.color, lineWidth: 3).frame(width: 14, height: 14).shadow(color: f.color, radius: 6)
                        Text("\(f.name) touch").font(EFont.body(13, .semibold))
                    }
                    .padding(.horizontal, 12).frame(height: 34).background(EColor.ground.opacity(0.85), in: Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
                }
                VStack {
                    Spacer()
                    if showHint {
                        Text("Tap to show controls").font(EFont.body(13, .semibold))
                            .padding(.horizontal, 14).frame(height: 34).background(EColor.ground.opacity(0.8), in: Capsule())
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }
            } else {
                topBar()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: cueFeeling)
        .task(id: immersive) {
            guard immersive else { showHint = false; return }
            withAnimation { showHint = true }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showHint = false }
        }
    }

    private func toggle() {
        withAnimation(.easeInOut(duration: 0.3)) { immersive.toggle() }
    }
}

/// Round button for the player's top bar.
struct PlayerBarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44).background(EColor.ground.opacity(0.85), in: Circle())
        }
        .accessibilityLabel(label)
    }
}
