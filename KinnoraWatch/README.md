# Kinnora for Apple Watch

The companion watch app for the Kinnora iPhone app. It plays the touches the iPhone sends, so
the wrist feels the same feeling as the ring.

## Xcode target

The `KinnoraWatch` watchOS target is already in `PulseLoop.xcodeproj` (added 2026-10-27). It is
built from this folder (`Info.plist` and this README are excluded), embedded in the iPhone app
under "Embed Watch Content", and installs with it.

- Bundle ID `dev.emotionringmy.ios.watchkitapp`, companion of `dev.emotionringmy.ios`, watchOS 10+.
- `Info.plist` adds `WKApplication` and the `mindfulness` background mode that **Start session**
  needs.
- Run the **PulseLoop** scheme on the iPhone. If the watch app doesn't appear on the watch, open
  the Watch app on the iPhone → Available Apps → Install.

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
