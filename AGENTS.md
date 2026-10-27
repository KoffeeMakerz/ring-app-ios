# Agent instructions — PulseLoop iOS

Read this before significant work in this repository.

## Required pre-read

1. Read `knowledge/INDEX.md` before significant work.
2. Read the relevant `knowledge/*.md` files before modifying a subsystem.
3. Inspect implementation code before proposing or applying changes.

## Scope discipline

1. Prefer small, verifiable changes.
2. Avoid unnecessary refactors.
3. Preserve known BLE behavior unless there is strong evidence and tests for a change.
4. Never treat undocumented BLE assumptions as confirmed behavior.

## Knowledge maintenance

1. Update the knowledge base when important technical discoveries are made.
2. Record important architectural decisions in `knowledge/decisions.md`.
3. Record durable protocol/device findings in `knowledge/discoveries.md`.

## Cross-platform check

1. Check the sibling Android implementation when a behavior spans protocols or ring families.
2. Requested sibling reference: `../PulseLoopAndroid`.
3. Current workspace sibling path: `../ring-app-android`.

## Validation before completion

1. Build and test affected functionality before declaring work complete.
2. Include protocol-level evidence (logs, packet bytes, parser path) when touching BLE.
3. Preserve upstream LICENSE and attribution requirements.

## BLE evidence policy

Use certainty labels in knowledge docs where relevant:

- `Status: source-confirmed`
- `Status: hardware-verified`
- `Status: unverified`

Only use `hardware-verified` when explicit real-device evidence exists.

## Keep iOS and Android aligned

Kinnora ships on iOS (`ring-app-ios`) and Android (`ring-app-android`) with the same tabs (Home,
Experiences, Practice, Meditate, Devices), flows and wording. **Any feature or flow change goes into
both apps in the same piece of work**, or the gap is written into `docs/emotion-app/parity.md` with
a reason. Keep model names, raw values, touch patterns and defaults identical across platforms.
`docs/emotion-app/parity.md` (same file in both repos) maps each iOS screen to its Android screen;
update it when a screen is added, renamed or removed.

## Store notes: update them with every change

`docs/store/app-store.md` and `docs/store/google-play.md` track what the App Store and Google Play
require, what's done and what's still open. **Any change that touches permissions, background
behaviour, data leaving the phone, AI features, health features, payments, store wording or videos
updates both notes in the same commit**: the affected rows plus a line in the change log at the bottom.
The same files live in ring-app-ios and ring-app-android; keep them identical (copy across). The
project doc `claude/store-compliance.md` mirrors them.
