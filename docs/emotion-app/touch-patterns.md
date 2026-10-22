# Ring touch patterns — v2 (2026-10-20)

The vibration patterns ("touches") the app plays on the ring for each feeling and for the calm cue. Both apps use the same values:
- iOS: `Feeling.durationsMs` in `Emotion/Model/Feelings.swift`, and `TouchPattern.calmCue` in `Emotion/Services/CalmCueMonitor.swift`.
- Android: `Feeling.durationsMs` and `TouchPattern.CALM_CUE` in `emotion/EmotionModel.kt`.

## Why they changed

v1 touches were barely noticeable on a real ring. Most supported rings (Colmi/Yawell, YCBT/R10M, CRP) have no real vibration control, only a fixed "find device" buzz:

| Ring family | Buzz length | Shortest time from one buzz start to the next |
|---|---|---|
| Colmi | ~300 ms | 600 ms |
| YCBT / R10M | ~400 ms | 700 ms |
| CRP | ~500 ms | 800 ms |

So every motor-on segment of a pattern becomes **one buzz**, whatever its length. v1 patterns came out as only 2–3 buzzes, and most of their rhythm was lost. RWfit rings and the phone's own motor (used when no ring is connected) do play the real lengths.

## Design rules (v2)

- **5–9 buzzes per touch**, in groups you can count.
- Buzzes inside a group start **~600–650 ms apart**, the fastest the Colmi family can do. Slower rings are pushed apart automatically.
- **0.9–1.3 s between groups**, so each feeling has its own countable shape.
- Every pattern starts and ends with a buzz, so they chain into experience sequences, with at least 4 s between feelings.
- Each touch is up to 8 s long (most are 4–7 s).

## The patterns

Durations alternate motor-on / motor-off, in milliseconds, starting with on.

| Touch | Rhythm | Buzzes | Durations (ms) | Length |
|---|---|---|---|---|
| Gratitude | 2 · 2 · 1 ("thank you, thank you, yes") | 5 | 350, 300, 350, 1200, 350, 300, 350, 1200, 500 | 4.9 s |
| Love | three heartbeats (short-long pairs) | 6 | 300, 300, 450, 1000, 300, 300, 450, 1000, 300, 300, 450 | 5.15 s |
| Joy | three quick triplets | 9 | 250, 350, 250, 350, 250, 900, ×3 (no trailing gap) | 6.15 s |
| Confidence | 1 · 1 · 3 (step, step, rise) | 5 | 450, 900, 450, 900, 300, 300, 300, 300, 600 | 4.5 s |
| Bliss | five taps speeding up, the last one longer | 5 | 300, 1300, 300, 1000, 300, 750, 300, 550, 700 | 5.5 s |
| Calm | four slow, even hums | 4 | 700, 1300, 700, 1300, 700, 1300, 700 | 6.7 s |
| Calm cue ("Slow down") | five hums, each gap longer, like a breath slowing down | 5 | 600, 700, 600, 1000, 600, 1400, 600, 1800, 600 | 7.9 s |

v1 for reference:
- gratitude: double tap, rest, tap
- love: heartbeat ×2
- joy: two flutters
- bliss: flutter + double tap
- calm: two long hums
- confidence: tap, rest, double tap
- calm cue: three hums, 800/1200/800/1800/800

## Where they're used

- Ring touches during experiences and practice sessions.
- Reminder cues. An experience plays its feelings' touches in order, at least 4 s apart.
- "Feel it" buttons.
- The calm cue.
- The composer's "Start from" blocks are the closest match from the block library. Saved custom touches are unchanged.

## If it's still not strong enough

The buzz itself can't be made stronger on fixed-buzz rings. Remaining options:
- Play each touch twice.
- Let the user pick "stronger" (more repeats) in the vibration check.
- Use RWfit's real vibration command where the ring supports it.

## Tested

Not yet on a real ring. To test, use Ring tab → "Feel each touch" (Android) or the feeling rows / "Feel it" (iOS). Record which touches are easy to tell apart.
