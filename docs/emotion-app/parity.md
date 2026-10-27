# Kinnora on iOS and Android: what matches

Both apps should offer the same tabs, flows and wording. When one app gets a feature, the other
gets it in the same piece of work, or the gap goes in the table below with a reason.

## Tabs

| Tab | iOS | Android |
|---|---|---|
| Home | `Views/Home/HomeView.swift` | `emotion/ui/HomeScreen.kt` |
| Experiences | `Views/Library/…`, builder, player | `ExperiencesScreen.kt`, `BuilderScreen.kt`, `PlayerScreen.kt` |
| Practice | `Views/Train/TrainingViews.swift` | `emotion/ui/PracticeScreens.kt` |
| Meditate | `Views/Meditate/…` | `MeditateScreens.kt` |
| Devices | `Views/Ring/RingViews.swift` | `RingScreen.kt` |

## Flows

| Flow | iOS | Android |
|---|---|---|
| Onboarding: welcome, consent, devices, vibration check, first vision, build, live it, first reminder | `EmotionOnboardingView.swift` | `OnboardingScreens.kt` (`OnboardingFlow`) |
| Practice: 7 sessions per feeling, settle 60 s (4 in, 7 out), feel with music, check in | `TrainingSessionView` | `TrainingSessionScreen` (the feel step reuses the player) |
| Live an experience from Home: settle, player, check in | `TrainingSessionView` with an experience | `TrainingSessionScreen` with an experience |
| Reminders: schedules (spread or set times), quiet hours, daily cap, pause, today's cues | `ReminderViews.swift`, `ReminderScheduler`, `CueDispatcher` | `RemindersScreens.kt`, `Reminders.kt` (`ReminderScheduler`) |
| Cue check-in after a reminder | `CueReceivedView` | `CueReceivedScreen` |
| Reminders on the watch (the watch plays them; the phone stays quiet) | `WatchLink.remindersOnWatch` | `WatchLink.remindersOnWatch` |
| Vibration check | `VibeTestView` | `VibeTestScreen` |
| Guides & help | `LearnView` | `LearnScreen` |
| Your stats + optional stats switches | `RingStatsSection` | `StatsSection` in `RingScreen.kt` |
| Delete emotion data | Devices → Privacy, export & delete | Devices → Privacy, export & delete |
| Calm cue when tense | `StressCueView` | `CalmCueScreen` |

## Data

Same fields and defaults on both: `ReminderRule`, `ReminderEvent`, `TrainingRecord`,
`EmotionProfile`. iOS keeps them in SwiftData; Android keeps them in `filesDir/emotion/data.json`
(`EmotionData.kt`).

## Differences, on purpose

| What | Why |
|---|---|
| Reminder timing | iOS can only run when the system wakes the app, so cues can drift. Android uses one inexact alarm (no exact-alarm permission), so cues can also land a few minutes off in battery saving. Both say so on the Reminders screen. |
| Ring pairing screen | Android still pairs in the original screens (`pairing` route), then returns. |
| Stats | iOS shows steps, heart, HRV and sleep cards. Android shows the latest heart rate, HRV and stress, and links to the original health screens for sleep and activity. |
| Image Playground | Apple only. |
| Developer tools (simulated ring, delivery test) | iOS DEBUG builds only. |
