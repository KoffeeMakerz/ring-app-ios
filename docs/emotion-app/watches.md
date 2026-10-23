# Watches: touches on the wrist

The ring app sends every touch it plays to a paired watch as well: practice, experiences,
reminders, the calm cue and tests. The Ring tab's watch card has a **Touches play on** setting:

| Setting | Behaviour |
|---|---|
| **Both** (default) | Touches play on the ring and on the watch. |
| **Ring** | Touches play on the ring only. |
| **Watch** | Touches play on the watch only. When no watch is reachable, they fall back to the ring. |

A reminder or calm cue now counts as delivered when either the ring or the watch can play it.

## Wear OS (Pixel Watch, Galaxy Watch…) — Android app

- **Phone side:** `emotion/WatchLink.kt`.
  - Finds watches by the `kinora_watch_app` capability.
  - Sends `/kinora/play` with `{"id","name","durations_ms":[on, off, …]}`.
  - `RingTouches.play` calls it, so every touch goes to the watch.
- **Watch app:** the `:wear` module in this repo (copied from kinora-watch).
  - It has the same applicationId as the phone app (`com.pulseloop`, plus `.debug` for debug builds) and the same release key. The Wear Data Layer requires both.
  - It plays touches with exact lengths and gaps, and receives them in the background (`WearableListenerService`), so the app doesn't need to be open.
- **Install for testing:** in Android Studio, pick the `wear` run configuration and the watch (paired over Wi-Fi or USB debugging), and run it. Then on the phone: Ring tab → watch card → **Look again** → **Test watch**.

## Apple Watch — iOS app

- **Phone side:** `Emotion/Ring/WatchLink.swift` (WatchConnectivity). `RingHapticsService.play` calls it.
- **Watch app source:** `KinnoraWatch/` at the repo root. It needs a one-time Xcode step to add the watchOS target; see `KinnoraWatch/README.md`.
- **Limitation:** watchOS only delivers live messages to a running app.
  - Touches arrive while Kinnora is open on the watch.
  - **Start session** on the watch keeps it listening with the wrist down for up to an hour. It uses a mindfulness extended runtime session.
  - Reminders reach the watch anyway, as the iPhone's forwarded notification. The feeling's touch plays if the app is open or the notification is tapped.
- The Taptic Engine can't do free-form vibration, so each "on" segment becomes one system tap at the pattern's timing.

## Not yet

- **Amazfit (Zepp OS):** waiting on the model and the approach (a mini-program, or direct Bluetooth on Android).
- **Reminder plan synced to the watch,** so a watch could buzz on time with the phone asleep. The watch apps can already receive a plan (`/kinora/reminders`, `"reminders"`), but the phone doesn't send it yet. That avoids duplicates with the phone's forwarded notifications.
- **The kinora-watch Flutter phone app** is superseded by this: the ring app is now the phone app for watches. The repo is kept for its watch-app sources and as a no-ring option.
