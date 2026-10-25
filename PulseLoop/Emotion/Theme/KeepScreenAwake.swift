import SwiftUI
import UIKit

/// Keeps the screen on while a session is showing (breathing, an experience, practice), so the
/// phone doesn't dim and lock halfway through. The rest of the app locks normally.
/// Counted, so overlapping screens (e.g. a player over a list) don't switch it off early.
@MainActor
enum ScreenAwake {
    private static var holders = 0

    static func hold() {
        holders += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func release() {
        holders = max(0, holders - 1)
        if holders == 0 { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

extension View {
    /// The screen stays on while this view is on screen.
    func keepsScreenAwake() -> some View {
        onAppear { ScreenAwake.hold() }
            .onDisappear { ScreenAwake.release() }
    }
}
