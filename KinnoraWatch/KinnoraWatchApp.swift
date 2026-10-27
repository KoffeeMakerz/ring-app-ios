import SwiftUI
import UserNotifications
import WatchKit

/// Kinnora on Apple Watch: plays the touches the Kinnora iPhone app sends, delivers the reminder
/// plan itself, and plays experiences on the wrist or starts them on the iPhone.
@main
struct KinnoraWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate
    @StateObject private var session = WatchSession.shared
    @StateObject private var store = WatchStore.shared
    @StateObject private var keepAwake = KeepAwake.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environmentObject(store)
                .environmentObject(keepAwake)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        WatchSession.shared.activate()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        WatchStore.registerCategory()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // A reminder arrives while Kinnora is open: play its touch right away.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        let durations = (info["durations_ms"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
        let feeling = WatchFeeling.named(info["feeling"] as? String)
        HapticPlayer.play(Pattern(name: feeling.name, durationsMs: durations.isEmpty ? feeling.durationsMs : durations))
        return [.banner, .list]
    }

    // A reminder was tapped or "Start" pressed: play its touch and open its experience or feeling.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        WatchStore.shared.open(reminderInfo: response.notification.request.content.userInfo)
    }
}
