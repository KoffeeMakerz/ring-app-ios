# Google Play notes (phone + Wear OS)

Last updated 2026-10-25. Policy names are Google Play Developer Policy sections.

## Blockers

| Area | Policy | Status | What to do |
|---|---|---|---|
| Self-update (`UpdateChecker`, `REQUEST_INSTALL_PACKAGES`) | Device and Network Abuse | **Blocker** | Play apps can't download or install their own updates. Remove `REQUEST_INSTALL_PACKAGES` and turn off the update checker in the Play build (a `play` flavor, or `BuildConfig` off). Keep it only for the GitHub APK build. |
| Exact alarms in the Wear OS app (`USE_EXACT_ALARM`) | Exact alarm permission | **Blocker** | `USE_EXACT_ALARM` is only for alarm-clock and calendar apps. Keep `SCHEDULE_EXACT_ALARM` (user-granted) and remove `USE_EXACT_ALARM` from `wear/src/main/AndroidManifest.xml`. |
| Third-party AI in the original health screens (the Coach uses OpenAI, Google Gemini and MiniMax) | User Data, AI-generated content | **Blocker** | Disclose it in the app before sending, in the privacy policy and in the Data safety form. Or remove or hide the Coach in the Kinnora build. If the Coach generates content, it needs an in-app way to report offensive output. |

## To do before submitting

| Area | Policy | Status | What to do |
|---|---|---|---|
| Health Connect | Health Connect permissions declaration | To do | Fill in the declaration for every `health.WRITE_*` permission and justify each. Request only the ones the app uses; the list is long, so trim it. Link the privacy policy. |
| Health apps declaration | Health apps | To do | Complete the Health apps declaration in Play Console. Wellbeing only, no medical claims. |
| Foreground service type `health` | Foreground service types | To do | Declare it in Play Console with a short video of the ring sync that needs it. |
| Location (fine and coarse) | Permissions, location | Check | Must be needed by a visible feature (workouts or BLE on old Android). No background location is requested; keep it that way. |
| Camera | Permissions | Check | Only if a visible feature uses it (barcode scan in the original screens). Otherwise remove it. |
| Data safety form | User Data | To do | Must match reality: health data stays on the phone or goes to Health Connect; the Coach's AI providers if kept; Strava if kept. |
| Wellbeing wording | Misleading claims | To do | Same rule as Apple: "practise a feeling", "reminds you to breathe"; no treatment claims. |
| Target API level | Target API | OK | Phone app targets 35. Wear app targets 34: raise it before Wear submission if Play requires a newer level. |
| Music and image rights | Intellectual property | Check | ElevenLabs commercial plan; image credits list. |
| App name "Kinnora" | Impersonation and IP | Check | Search Play and trademarks. |

## Feature notes

| Feature | Status | Notes |
|---|---|---|
| Ring over Bluetooth | OK | `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`. |
| Calm cue | OK | Wellbeing wording only. |
| Keep screen on during sessions | OK | `keepScreenOn` only while a session shows. |
| Wear OS app (`:wear`) | To do | Same applicationId and signing key as the phone app. Needs Wear screenshots and must pass Wear OS app quality: round screens, works when the phone is away. Wear apps are reviewed separately. Branch `feature/watch-extension`. |
| Promo video | OK | Live-action is allowed on Play (YouTube link), so the 2-minute and 30-second cuts can be used. |
| Apple Intelligence images | Not applicable | iPhone only. Android has no free on-device image generation. |

## Change log

- 2026-10-25: Note created. Flagged self-update, `USE_EXACT_ALARM` in the Wear app and the Coach's third-party AI as blockers. Added Health Connect, foreground service, Wear OS and promo video notes.
