# iOS Discoveries

This file keeps durable, implementation-level findings.

## Coordinator order is load-bearing for ambiguous advertisements

Discovery:

First-match coordinator order determines family assignment for overlapping name/service patterns.

Where:

- `PulseLoop/RingProtocol/RingBLEClient.swift`
- Coordinator files in `PulseLoop/RingProtocol/`

Why it matters:

Changing order can silently redirect rings into incorrect protocol stacks.

Status: source-confirmed

## Spot measurement completion semantics can override naive settle assumptions

Discovery:

Certain families provide explicit completion verdicts and ring-owned logged values that should govern final persistence behavior.

Where:

- `PulseLoop/Services/RingSyncCoordinator.swift`
- Family decoders/sync engines under `PulseLoop/RingProtocol/`

Why it matters:

Avoids mismatches between provisional app rows and synced ring history.

Status: source-confirmed

## jring history synchronization requires day-offset correctness and sequencing discipline

Discovery:

Day offset semantics and one-day-at-a-time request ordering are required to avoid partial or truncated history imports.

Where:

- `PulseLoop/RingProtocol/JringHistorySync.swift`

Why it matters:

Incorrect sequencing can look superficially healthy while missing sleep segments.

Status: source-confirmed

## CRP wear/contact signals are critical when triaging failed spot measures

Discovery:

Wear-state events can explain no-reading outcomes without implying protocol breakage.

Where:

- `PulseLoop/RingProtocol/CRPDecoder.swift`
- `PulseLoop/RingProtocol/CRPSyncEngine.swift`

Why it matters:

Improves user guidance and prevents misattribution of failures to transport logic.

Status: hardware-verified

## Haptic command existence is not proof of custom vibration support

Discovery:

Find-device command paths exist across families, but source does not confirm programmable intensity/duration/repeat support.

Where:

- Family encoders/protocols under `PulseLoop/RingProtocol/`

Why it matters:

Custom vibration should remain an explicit hardware-validation target, not an inferred capability.

Status: unverified
