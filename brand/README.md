# Kinora brand kit

Everything needed to use the Kinora brand in the apps, the website, the store listings and social media. Regenerate the files with `python3 build_brand_kit.py`.

**Kinora** — *Feel · Align · Become*

## The idea

Kinora links a feeling to a touch on your ring. The mark says that in one picture:
- **The ring** is the one you wear, lit along its lower-right edge like an eclipse: a quiet moment catching the light.
- **The four-point star** is the feeling you practise until a touch can bring it back.

## Logo files (`logo/`, all SVG, vector)

| File | Use |
|---|---|
| `kinora-mark-on-plum.svg` | App icon and avatar: the mark on the plum ground |
| `kinora-mark.svg` | The mark alone (transparent), on dark backgrounds |
| `kinora-mark-gold-mono.svg` / `-ink-mono.svg` / `-white-mono.svg` | One-colour mark: print, emboss, engraving, small sizes, light backgrounds |
| `kinora-logo-stacked-dark.svg` / `-light.svg` | Mark + wordmark + tagline, centred: splash screens, posters, packaging |
| `kinora-logo-horizontal-dark.svg` / `-light.svg` | Mark + wordmark side by side (transparent): headers, website, email |
| `kinora-wordmark-dark.svg` / `-light.svg` | Wordmark only, where the mark already appears nearby |
| `kinora-social-card.svg` | Link preview / Open Graph card |

The wordmark letters are outlined paths (from DejaVu Sans ExtraLight, a free licence), so the files look the same everywhere with no font installed.

Ready-made PNGs are in `png/` (logos and marks), `icons/` (app icon from 1024 px down to 16 px, plus `favicon.ico`) and `social/` (1200×630 card, 400×400 avatar).

## Using the logo

- **Which version:** on dark grounds use the gradient mark with its glow. On light grounds use the one-colour gold or ink version: the glow only works on dark.
- **Clear space:** keep at least the star's height (≈ 40% of the ring's radius) clear on every side.
- **Minimum size:**
  - The mark with glow: 48 px / 12 mm across.
  - Below that, use the one-colour mark; it works down to 16 px.
  - The wordmark: 80 px / 20 mm wide.
- **Don't:**
  - stretch, rotate or outline the mark;
  - move the star off-centre;
  - put the glow version on a light or busy photo;
  - change the gold to another colour;
  - set "Kinora" in a different font in the logo;
  - add effects (bevels, heavy shadows).

## Colour (`colors/`)

| Token | Hex | Use |
|---|---|---|
| plum-900 | `#120B1C` | Deepest ground, gradient edge |
| plum-800 | `#1E1230` | App backgrounds, Android icon background |
| plum-700 | `#341E48` | Gradient centre, cards on dark |
| plum-500 | `#5B3A73` | Accents on dark, selected states |
| gold-700 | `#B8805A` | Gold on light backgrounds, one-colour mark |
| gold-500 | `#E2B48C` | Main gold, tagline on dark |
| gold-300 | `#FFE3C8` | Gold highlight (lit edge) |
| star | `#FFECD6` | The star, wordmark on dark |
| glow | `#FFC9A6` | Light on the ring's edge (only as a soft glow) |
| rose-300 | `#D9A7A7` | Secondary accent (love, warmth) |
| blush-100 | `#F1D9D2` | Soft light backgrounds |
| cream-50 | `#F6F0E9` | Light ground, print paper |
| ink-900 | `#3C2428` | Text and wordmark on light |
| sage-500 | `#7F9A86` | Calm accent (meditation, nature) |

**Gradients:**
- **Ground:** plum-700 → plum-900, radial from just above the centre.
- **Gold:** gold-700 → gold-500 → gold-300, at 135°.

**Ready to use:** `tokens.json` (design tools / web build), `kinora.css` (CSS variables), `KinoraColor.swift` (SwiftUI), `KinoraColor.kt` (Jetpack Compose).

The apps' feeling colours (gratitude amber, love pink, joy yellow, calm blue, confidence green, bliss violet) stay as they are inside the product. The brand palette is for the brand: icon, logo, marketing and store.

## Type

- **Wordmark:** light-weight capitals, letter-spacing ≈ 0.45 em ("K I N O R A"). The tagline uses the same face, smaller, spaced ≈ 0.18 em, joined by " · ".
- **In the apps today:** the system font (SF Pro / Roboto) in light and regular weights.
- **Recommended for marketing and a future in-app display face** (all free, Google Fonts):
  - *Jost* Light or *Montserrat* Light: geometric sans, close to the wordmark.
  - *Cormorant Garamond*: an elegant serif for headlines.
- Keep body text in a plain, readable sans.

## Voice

- **Calm, warm and brief.** Speak to one person, in the present tense, as if the good thing is already real ("It's happening. Let the joy rise.").
- **No hype, no medical claims.** It's a practice, not a promise.
- Short sentences, everyday words. **Kinora** is always written with a capital K and the rest lowercase in text. All capitals are for the logo only.

## Where it's used now

| Platform | Item | Location |
|---|---|---|
| iOS | App icon | `PulseLoop/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` |
| iOS | In-app logo | `pulseloop-logo` image set (Kinora mark) |
| iOS | Welcome screen | SwiftUI `KinoraMark` / `KinoraWordmark` |
| Android | Launcher | `mipmap-*/ic_launcher*.png` (adaptive background `#1E1230`) |
| Android | Logo | `drawable-nodpi/pulseloop_logo.png` |

## Later: the rest of the PulseLoop name (noted 2026-10-21, not done yet)

Some things still say PulseLoop. They'll be renamed to Kinora when the original PulseLoop screens are reworked (some of those screens will be redesigned, some reused in Kinora):
- **Original health screens:** they now show Kinora text, but still use the PulseLoop layout and colours. Restyle them with this kit.
- **Names inside the code:** iOS targets, folders and the Xcode project (`PulseLoop`, `PulseLoopWidgets`, `PulseLoopLiveActivity`); the Android package `com.pulseloop`; the image asset names `pulseloop-logo` / `pulseloop_logo`.
- **Widget and Live Activity display names.**
- **Song files:** the MP3 artist tag still says "PulseLoop".
- **Kept on purpose until checked:**
  - the ring protocol app identifier;
  - the HTTP user agents;
  - Health Connect device metadata, because changing it splits records already exported;
  - bundle / application IDs: these change only at store setup.
