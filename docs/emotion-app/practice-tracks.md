# Practice tracks (1 minute per feeling)

Short instrumental tracks for practising a single feeling. A practice session now runs:
settle in (1 min, 4/7 breathing) → feel it with the practice track (1 min, 3 ring touches) → check in.
The full songs are still available under "Change".

| Feeling | Track | File | Ring cues (s) |
|---|---|---|---|
| Gratitude | Quiet Gratitude | practice_gratitude.mp3 | 24, 36, 48 |
| Love | Warm Against Time | practice_love.mp3 | 14, 32, 48 |
| Joy | Joy in Motion | practice_joy.mp3 | 18, 34, 46 |
| Bliss | Radiant Drift | practice_bliss.mp3 | 16, 26, 38 |
| Calm | Still Water Breath | practice_calm.mp3 | 16, 26, 42 |
| Confidence | Unshakable Rise | practice_confidence.mp3 | 18, 38, 48 |

- Made with ElevenLabs Music v2.5: 60 s, instrumental. They're on the "Kinnora practice tracks" flow.
- Finished with `scripts/songs/finish_song.py finish --no-tone`: retuned A=444, -16 LUFS, 192 kbps.
  No 528 Hz layer, because most of the keys clash with it.
- Cue markers are the loudest 2-second windows from `finish_song.py analyse`, at least 10 s apart.
- iOS: `MusicTrack.practice` and `MusicTrack.practice(for:)`; the files are in `PulseLoop/Emotion/Music`.
- Android: `MusicTrack.practice` and `practiceFor()`; the files are in `res/raw`. Android has no practice screen
  yet, so the tracks are listed in Songs → Practice tracks.
