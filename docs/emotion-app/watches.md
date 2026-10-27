# Watches: touches on the wrist

The ring app sends every touch it plays to the devices you use: practice, experiences, reminders, the calm cue and tests.

## Devices tab (was "Ring")

| Setting | Behaviour |
|---|---|
| **Use a ring** (on by default) | Off: no touches go to a ring; it is disconnected and never auto-reconnected. |
| **Use a watch** (on by default) | Off: nothing is sent to the watch. |
| **Ring first** (default) | Touches go to the ring; the watch plays only when no ring is connected. |
| **Both** | The ring and the watch play every touch together. |

With neither a ring nor a watch, the app still works: the phone vibrates (Android) or the touch is shown on screen. First launch asks which devices you use: onboarding on iOS, a one-time question on Android.

## The watch apps (v2)

Both watch apps look alike, in the spirit of Apple's Mindfulness app:

- **Home tiles:** Experiences, Feel a touch, Reminders, and (Apple Watch only) Listen to iPhone.
- **Experiences:** synced from the phone. **Play here** shows a breathing bloom in the current feeling's colour and plays each cue's touch on the wrist, with no music. **Play on phone** starts it on the phone. If Kinnora isn't on screen there, a notification opens the player.
- **Reminders:** the upcoming plan, delivered by the watch itself.
  - Apple Watch: as notifications; tap or **Start** plays the touch. The iPhone schedules none while the watch has them, so there are no duplicates.
  - Wear OS: exact alarms play each touch on time, even with the phone asleep.
- **Sync:** application context on iOS, data item `/kinora/sync` on Android. Both keep the latest copy on the watch.

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
