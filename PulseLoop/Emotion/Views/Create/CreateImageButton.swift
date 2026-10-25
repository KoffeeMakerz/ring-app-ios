import ImagePlayground
import SwiftUI

/// "Create with Apple Intelligence": Apple's Image Playground sheet, which makes the picture on
/// this iPhone. Free, nothing is uploaded, and Apple applies its own content rules.
///
/// Store-safe choices:
/// - Only Apple's on-device styles (animation, illustration, sketch). The ChatGPT styles iOS 26
///   offers in Image Playground send the prompt to OpenAI, which would need a third-party AI
///   consent screen (App Review 5.1.2(i)), so they're left out.
/// - Uses the sheet, not `ImageCreator` (Apple is retiring `ImageCreator` in iOS 27).
/// - Hidden on iPhones without Apple Intelligence, so nobody sees a button that can't work.
/// - Pictures stay private in the person's own experiences; nothing is shared with other users.
struct CreateImageButton: View {
    /// What to draw, prefilled from the vision (the person can change it in the sheet).
    let concept: String
    var disabled = false
    /// Called with the created image's file (a temporary URL from the system).
    let onCreated: (URL) -> Void

    var body: some View {
        if #available(iOS 18.1, *) {
            PlaygroundButton(concept: concept, disabled: disabled, onCreated: onCreated)
        }
    }
}

@available(iOS 18.1, *)
private struct PlaygroundButton: View {
    let concept: String
    let disabled: Bool
    let onCreated: (URL) -> Void
    @Environment(\.supportsImagePlayground) private var supported
    @State private var showing = false

    var body: some View {
        if supported {
            VStack(alignment: .leading, spacing: 8) {
                Button { showing = true } label: {
                    Label("Create with Apple Intelligence", systemImage: "wand.and.stars")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(disabled)
                Text("Describe a scene from your vision and Image Playground draws it on this iPhone. Free, and nothing is uploaded.")
                    .font(EFont.body(12)).foregroundStyle(EColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .imagePlaygroundSheet(isPresented: $showing, concept: concept) { url in
                onCreated(url)
            }
            .onDeviceStylesOnly()
        }
    }
}

private extension View {
    /// Limits Image Playground to Apple's on-device styles (no external ChatGPT styles).
    @ViewBuilder
    func onDeviceStylesOnly() -> some View {
        if #available(iOS 18.4, *) {
            imagePlaygroundGenerationStyle(.illustration, in: [.illustration, .animation, .sketch])
        } else {
            self
        }
    }
}
