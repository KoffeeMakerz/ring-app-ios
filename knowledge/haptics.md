# iOS Haptics and Find Device

This file focuses on ring-side feedback commands and certainty levels.

## Entry points

- User action path: `RingSyncCoordinator.findDevice()` in `PulseLoop/Services/RingSyncCoordinator.swift`
- Family dispatch: active `RingSyncEngine.findDevice()` implementation

Status: source-confirmed

## Family command mapping

### CRP

- Path: `RingSyncCoordinator` -> `CRPSyncEngine` -> `CRPProtocol.findDevice(enable)`
- Command family: group `0x09`, cmd `0x02`

Status: source-confirmed

### Colmi/QRing

- Path: `RingSyncCoordinator` -> `ColmiSyncEngine` -> `ColmiEncoder.findDevice()`
- Command bytes: `0x50 0x55 0xAA`

Status: source-confirmed

### YCBT

- Path: `RingSyncCoordinator` -> `YCBTSyncEngine` -> `YCBTEncoder.findDevice()`
- Command family: app control `0x03/0x00` style trigger

Status: source-confirmed

### LuckRing

- Path: `RingSyncCoordinator` -> `LuckRingSyncEngine` -> `LuckRingEncoder.findDevice()`
- Command uses family find-device data type (`11` constant family)

Status: source-confirmed

### jring

- Family includes find-device capability and command wiring in protocol paths.

Status: source-confirmed

### RWfit

- Find-device behavior is not exposed as an active, reliable capability path in current source.

Status: source-confirmed

## Ring alarms/reminders and motor behavior

- Protocol surfaces for reminders/notifications exist in several families.
- Source does not provide a uniform API exposing explicit vibration intensity/duration/repeat knobs across families.

Status: source-confirmed

## App-side phone haptics vs ring-side feedback

- iOS UI uses phone haptics in multiple interaction flows.
- Phone haptics are independent from ring motor behavior and should not be used as evidence for ring vibration support.

Status: source-confirmed

## Custom vibration pattern support

Current understanding:

- No cross-family custom vibration pattern builder exists in app source.
- Existing commands appear mostly fixed-purpose (find-device/reminder-like triggers).

Status: unverified

## Cross-platform notes

- Ring-side find-device command coverage is broadly parallel with Android.
- Platform UI haptic behavior differs and is not protocol-equivalent to ring motor control.

Status: source-confirmed

## Haptic capability questions to verify on physical hardware

1. On each family, does find-device always correspond to vibration (not tone/LED-only behavior)?
2. Can repeated command invocation form reliable repeatable patterns without side effects?
3. Do hidden payload variants alter duration/intensity/repeat for any family?
4. Are reminder/alarm commands routed through the same physical motor path as find-device?
5. Is there firmware-specific behavior where command acknowledgment occurs but no physical feedback occurs?
6. Can any family expose custom pattern capability not yet surfaced in app UI?
