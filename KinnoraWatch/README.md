# Kinnora for Apple Watch

The companion watch app for the Kinnora iPhone app. It plays the touches the iPhone sends, so
the wrist feels the same feeling as the ring.

## One-time Xcode setup

The source is ready in this folder. Xcode has to create the watch target, because a watch app
must be a target of the iPhone app's project.

1. Open `PulseLoop.xcodeproj`. Choose **File → New → Target… → watchOS → App**, then Next.
2. Fill in the form:
   - **Product Name:** `KinnoraWatch`.
   - **Watch App for Existing iOS App:** checked, with **PulseLoop** selected.
   - **Interface:** SwiftUI. **Language:** Swift.
   - Leave Notification Scene off.
   Then press Finish, and press Activate if asked.
3. Xcode creates a folder called `KinnoraWatch Watch App`. Delete its `ContentView.swift` and
   `KinnoraWatchApp.swift` (Move to Trash). Then drag every `.swift` file from this
   `KinnoraWatch/` folder into it. Choose **Copy items if needed**, with only the watch target ticked.
4. Select the watch target. Under **Signing & Capabilities**:
   - pick your team;
   - press **+ Capability → Background Modes**;
   - tick **Session type: Mindfulness**. "Start session" on the watch needs this.
5. Under **General**, set **Display Name** to `Kinnora`. The bundle ID should be the iPhone app's ID plus
   `.watchkitapp`; Xcode fills that in.
6. Run the **PulseLoop** scheme on your iPhone. The watch app installs with it. If it doesn't
   appear, open the Watch app on the iPhone and install Kinnora under **Available Apps**.

## How it works

- The iPhone (`WatchLink.swift`) sends `["type": "play", "pattern": [...]]` over
  WatchConnectivity whenever it plays a touch: practice, experiences, reminders, the calm cue
  and tests. The Ring tab's **Touches play on** setting chooses Ring, Watch or Both.
- watchOS only delivers live messages to a running app, so touches arrive while Kinnora is open
  on the watch. **Start session** keeps it running with the wrist down for up to an hour, which
  is enough for a practice or an experience.
- Reminders reach the watch even when the app is closed. The iPhone's cue notification is
  forwarded to the watch. If Kinnora is open when one arrives, or the person taps it, the
  feeling's touch plays.
- The Taptic Engine can't do free-form vibration. Each "on" segment becomes one system tap,
  stronger for longer segments, at the pattern's timing.
