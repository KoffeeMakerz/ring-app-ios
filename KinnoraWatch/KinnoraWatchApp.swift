import SwiftUI
import UserNotifications
import WatchKit

/// Kinnora on Apple Watch: plays the touches the Kinnora iPhone app sends, so the wrist feels the
/// same feeling as the ring. It ships inside the iPhone app as its companion.
@main
struct KinnoraWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate
    @StateObject private var session = WatchSession.shared
    @StateObject private var keepAwake = KeepAwake.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environmentObject(keepAwake)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        WatchSession.shared.activate()
        UNUserNotificationCenter.current().delegate = self
    }

    // A Kinnora reminder (forwarded from the iPhone) shows while the app is open: play its feeling's touch.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let pattern = Pattern(reminderInfo: notification.request.content.userInfo) { HapticPlayer.play(pattern) }
        return [.banner, .list]
    }

    // A reminder was tapped: play its touch.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let pattern = Pattern(reminderInfo: response.notification.request.content.userInfo) { HapticPlayer.play(pattern) }
    }
}
