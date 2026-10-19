# Emotion app — test log

What was tested, how, what broke, and what is still untested. Add a new dated section per test round; keep older rounds for history.

## How we test (iOS)

- **Build:** Xcode on the Mac, scheme `PulseLoop`, destination **iPhone 17 Pro simulator (iOS 26.5)**, branch `feature/emotion-app`. Press Run (builds + installs + launches).
- **Ring:** the **simulated ring** (`Emotion/Ring/SimulatedRing.swift`). It's on by default on the Simulator target. Every buzz shows as a yellow glow on the floating ring overlay, and on device it also vibrates the phone. Heart data comes from the selected scenario (Resting / Coherent breathing / Tense, still / After workout / No signal).
- **Driving the UI:** Claude tapped through the app via computer use in the Simulator window.
  - Taps and text entry go through accessibility.
  - Scrolling = a swipe gesture (drag); mouse-wheel scrolling doesn't reach the simulator.
  - Text typed this way replaces the whole field. Multi-line `TextField(axis: .vertical)` doesn't update SwiftUI bindings this way (one reason vision points are now single-line).
- **Crashes:** read from Xcode's debug navigator / console when the app freezes.
- **Fresh start:** Ring tab → Developer → "Restart onboarding", or delete the app from the simulator.
- **Legacy UI:** Ring tab → Developer → "Switch to PulseLoop UI" (key `emotion.legacyPulseLoopUI`).

## Round 1 — 2026-10-19 (iOS, simulator)

Commits: `21a8507`, `63e7528`, plus `044958a`.

### Tested and passing

| Area | Screen(s) | How | Result |
|---|---|---|---|
| Build | — | Xcode Run | Builds with 0 errors (40 warnings are pre-existing PulseLoop ones) |
| Onboarding | 1.1 Welcome → 1.2 Consent → 1.3 Pair → 1.4 Vibration check → 1.5 Choose feeling | Tapped through; connected simulated ring | Pass |
| Notifications permission | after consent | Allowed in simulator | Pass |
| Vibration check | 1.4 | One buzz → two buzzes (gap ladder) → comfort | Pass; saves min gap + comfort |
| First training | 2.1 Intro → 2.2 Settle / Feel → 2.3 Reflect → 2.4 First reminder | Skip-to-music, cue timeline, rating, reminder 3/day | Pass |
| Home | 3.1 | Feeling card, practise, "feel rhythm now", next cue card, feeling ladder | Pass (next cue shows "tomorrow" late in the evening) |
| Library Explore | 3.2 | Theme chips, track list, "make a song — coming later" | Pass |
| Create experience | 3.4 | Name + vision points, save, edit, reopen | Pass after fixes |
| Feeling → touch | 3.4 | Switched Gratitude → Love | Suggested touch follows the feeling |
| Touch picker | 3.4b | Played feeling touches and simple alerts, selected | Pass |
| Touch composer | 3.4c | Added blocks / rests, removed a block, renamed, "Feel it", saved | Pass; 8.0 s cap disables all blocks |
| Custom touch use | 3.4b → 3.4 | Saved custom appears under "My touches", selected, applied | Pass |
| Your photos | 3.4a | Picked 3 sample photos (ordered 1–3), "Use these" | Pass (but see permission issue below) |
| Cue mode | 3.4 | Switched Auto → Tap | Pass after fix |
| Play experience | 3.3a | Slideshow + music clock, Vision sheet, back to slideshow | Pass |
| Training from experience | 2.2 | Real photos as slides, vision point as prompt, custom touch, Tap mode ("1 tap") | Pass after fix |
| Persistence | — | Relaunched app; experiences, custom touch, photos, cue mode kept | Pass |
| Meditate | 4.3 → 4.4 → 4.5 | Coherence session, ring buzz on inhale, live heart on, finish | Pass; "High coherence" with the coherent scenario |
| Ring tab | 5.1 | Simulated ring card, stats toggles | Pass |
| Simulator overlay | 6.3 | Open menu, open panel, drag to move, shows over full-screen sessions | Pass |
| Simulator panel | 6.2 | Feeling touches, profiles, heart scenarios | Opens and renders |

### Bugs found and fixed

1. **Build failure:** two files named `OnboardingFlowView.swift` gave "Multiple commands produce". Renamed ours to `EmotionOnboardingView.swift`.
2. **Crash:** opening the experience player crashed with "No Observable object of type EmotionRouter" because full-screen covers and sheets don't inherit it. The router is now passed in explicitly.
3. **Builder:** vision points didn't save from multi-line fields. Points are now single-line with next/done, and there's a keyboard Done button.
4. **Builder:** the tab bar showed over the form. It's now hidden.
5. **Composer:** "Short rest", "Long rest" and the "Start from" chips only reacted to taps on their text. The whole box is now tappable.
6. **Composer:** it always started from the Gratitude touch. It now starts from the experience's feeling.
7. **Long custom touches:** the glyph overflowed into the label. Glyphs now shrink to fit their slot.
8. **Picker button:** "Use Studio heartbeat" wrapped to two lines. Long names now say "Use this touch".
9. **Training:** it showed the feeling's default glyph instead of the experience's custom touch, and the reflect buzz used the default touch too. Both now use the experience's touch.
10. **Tap cue mode was ignored:** auto cues still fired. Tap mode now hides the markers, shows a tap count, and fires only when the user taps.
11. **Overlay:** it covered content at the top right and was hidden on full-screen sessions. It now sits bottom-right above the tab bar, can be dragged, and shows everywhere.
12. **Small copy fixes:**
    - "0 of 0 today" → "none left today" / "Next ring cue tomorrow".
    - "1 points" → "1 point".
    - Vibration check "Done" → "That's fine".
    - Meditation summary said "1 MIN" for a 23 s session; it now shows seconds.
13. **Training:** the placeholder slide caption overlapped the prompt text. It's hidden in training.

### Open issues and decisions

- **Photo permission (decision needed).** Slideshows reload photos by Photos-library ID, which needs library access.
  - After picking, iOS asks for full or limited access, and limited access makes the user pick the same photos again.
  - With limited access, iOS asks "Select more / Keep current" on every launch.
  - **Recommendation:** when photos are picked, store a resized private copy inside the app (still on-device, never uploaded). That means no library permission and a single pick. The cost is about 200–400 KB per photo.
- **Music doesn't follow the feeling.** Changing Gratitude → Love keeps the Gratitude track. Consider suggesting a matching track.
- **Locked feelings.** The builder lets you pick a feeling that is still locked in training (e.g. Love before 4 Gratitude sessions). Decide whether that's intended.
- **Overlay.** Its dragged position resets on relaunch (by design for now), and it isn't shown inside sheets.

### Not yet tested

- **"App images" tab** in 3.4a (built-in image sets).
- **Reminders end to end.** A notification arriving → 4.2 Cue received. Needs a short-interval rule or a test trigger.
- **Reminders screen** (4.1): rule editor and quiet hours sheet.
- **Learn** (5.3) and **Calm cue** (5.2, future feature).
- **Simulator panel actions in depth.** Each profile (Colmi / R10M / CRP / RWfit) timing, fault injection (delay, drop 1 in 5, low battery), the log, and Disconnect / Reconnect handling in screens.
- **Heart scenarios.** Tense / After workout / No signal during meditation.
- **Real audio.** No bundled tracks yet, so playback runs on a silent clock.
- **Real ring.** Pairing a real ring, its buzz timing, and ring-stored alarms (`RingAlarmWriter` is a stub).
- **Phone haptics.** "Vibrate phone" mirroring only works on a physical iPhone.
- **Android.** Not built yet.
