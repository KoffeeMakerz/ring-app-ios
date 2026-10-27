# App Store notes (iPhone + Apple Watch)

Last updated 2026-10-25. Guideline numbers are from Apple's App Review Guidelines.

## Blockers

| Area | Guideline | Status | What to do |
|---|---|---|---|
| Third-party AI in the original health screens (the Coach uses OpenAI, Google Gemini and MiniMax) | 5.1.2(i) | **Blocker** | Before any personal data goes to an outside AI, show a consent screen naming the provider and what's sent, and say so in the privacy policy. Or remove or hide the Coach in the Kinnora build. |
| Reviewer has no ring | 2.1 (completeness) | **Blocker** | App Review must be able to try the app. Ship a reviewer path: the phone works without a ring (meditation, experiences, practice with on-screen cues), and add App Review notes plus a short video of the ring in use. The simulated ring is DEBUG-only, so it doesn't count. |

## To do before submitting

| Area | Guideline | Status | What to do |
|---|---|---|---|
| Health and wellbeing claims | 1.4.1, 2.3 | To do | Keep all wording to wellbeing: "practise a feeling", "reminds you to breathe". No "reduces stress", "treats anxiety", "proven", "rewires your brain". Check the app text, store text, screenshots and video. |
| HealthKit (Apple Health) | 5.1.3 | To do | Privacy policy must cover health data. Never use it for ads or sell it. Purpose strings must explain each type read and written. Request only the types the app uses. |
| Privacy policy and nutrition label | 5.1.1 | To do | Policy URL in App Store Connect and in the app. The label must match reality, including the Coach's AI providers. (Strava was removed on 2026-10-25.) |
| Account and data deletion | 5.1.1(v) | Check | If any feature creates an account or link (the Coach), deletion must be possible in the app. "Privacy, export & delete" exists; confirm it covers everything. |
| Privacy policy and nutrition label | 5.1.1 | To do | Policy URL in App Store Connect and in the app. The label must match reality, including the Coach's AI providers and Strava if kept. |
| Account and data deletion | 5.1.1(v) | Check | If any feature creates an account (Strava link, Coach), deletion must be possible in the app. "Privacy, export & delete" exists; confirm it covers everything. |
| Background modes | 2.5.4 | Check | Declared: bluetooth-central (ring), location, fetch, processing. Location in the background must be needed by a visible feature (workouts in the original screens). Otherwise remove it. |
| Developer and legacy screens | 2.5.19 (Oct 2026) | Check | Developer tools are DEBUG-only. Make sure the "original health screens" switch and the simulated ring can't be reached in release, and nothing undocumented is hidden. |
| Music rights | 5.2 | Check | Songs and practice tracks were made with ElevenLabs. Commercial use needs a paid ElevenLabs plan that grants it. Keep the plan and invoices on file. |
| Images | 5.2 | Check | Built-in images come from free-licence sources (see `image-credits` in the project). Keep the credits list current. |
| Name "Kinnora" | 5.2.1 | Check | Search App Store names and trademarks before the listing. |
| Age rating | 1.2.1, questionnaire | Check | Answer the questionnaire honestly, including the July 2026 social and user-content questions. Experiences are private, not shared. |

## Feature notes

| Feature | Status | Notes |
|---|---|---|
| Ring over Bluetooth | OK | Purpose strings are set. Pairing works without accounts. |
| Reminders | OK | Local notifications only; nothing is sent off the phone. |
| Calm cue | OK | Wording: "reminds you to breathe". It doesn't claim to detect or treat stress. |
| Keep screen on during sessions | OK | Only while a session screen shows. |
| Apple Intelligence images (Image Playground) | OK | On-device styles only (no ChatGPT styles), so no third-party AI data. Hidden on iPhones without Apple Intelligence. Private images, not shared. Uses the sheet API, not `ImageCreator` (retired in iOS 27). Branch `feature/image-playground`. |
| Devices (ring / watch switches, ring first) | OK | Nothing is required: with no ring or watch the app still works. Onboarding asks which devices you use. |
| Reminders on the watch | OK | With the watch app installed, the watch delivers the reminder plan as its own notifications and the iPhone schedules none (no duplicates). A tap or "Start" plays the feeling's touch; the watch can't play a custom touch while the app is closed. |
| Apple Watch app | To do | Companion target is in the project (`KinnoraWatch`, bundle `dev.emotionringmy.ios.watchkitapp`); first build succeeded 2026-10-27. Needs its own icon, screenshots and a working experience without the iPhone app open. Mindfulness background mode is used for "Start session": explain it in the review notes. Branch `feature/watch-extension`. |
| Apple Watch app | To do | Companion target added in Xcode (see `KinnoraWatch/README.md`). Needs its own icon, screenshots and a working experience without the iPhone app open. Mindfulness background mode is used for "Start session": explain it in the review notes. Branch `feature/watch-extension`. |
| App Preview video | To do | Must be screen recordings of the app only: no people, no filmed ring. Use the App Store cut in the "Kinnora explainer video script" doc. |
| Music when the screen locks | Check | There's no `audio` background mode, so music stops when the phone is locked. Fine for review; a product decision. |

## Change log

- 2026-10-27: Apple Watch app v2: experiences (play on the watch or the iPhone), reminders list, reminders delivered by the watch. Devices tab with ring and watch switches; the ring comes first.
- 2026-10-27: Apple Watch target added to the Xcode project and built. Still needs its own app icon and watch screenshots before submission.
- 2026-10-25: Strava removed from the app (no third-party account link or uploads; old tokens are cleared on launch). Removes the Strava rows from the privacy label and account deletion.
- 2026-10-25: Note created. Added Image Playground (on-device only), the watch app, keep-screen-on and the screen-recording-only App Preview rule. Flagged the Coach's third-party AI and the reviewer-without-a-ring path as blockers.
