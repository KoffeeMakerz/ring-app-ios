# iOS Testing and Debugging

## Build and test commands

From repository root, example local commands:

```bash
xcodebuild -project PulseLoop.xcodeproj -scheme PulseLoop -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project PulseLoop.xcodeproj -scheme PulseLoop -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Status: source-confirmed

## Test focus areas

Useful test locations:

- `PulseLoopTests/PairingMatchingTests.swift`
- `PulseLoopTests/*Protocol*`
- `PulseLoopTests/*Decoder*`
- `PulseLoopTests/*SyncEngine*`
- `PulseLoopTests/SpotMeasurementGateTests.swift`

Status: source-confirmed

## BLE prerequisites

1. Bluetooth enabled on device/simulator constraints understood (real BLE requires physical iPhone).
2. Ring charged and nearby.
3. Clean prior app state when validating discovery routing changes.
4. Validate family-specific behavior with representative hardware where possible.

Status: source-confirmed

## CoreBluetooth and app config anchors

- Client entry: `PulseLoop/RingProtocol/RingBLEClient.swift`
- Background BLE/restoration behavior uses central manager restoration keys in BLE client and app configuration.
- Entitlements and plist behavior should be checked before claiming background BLE reliability.

Status: source-confirmed

## Diagnostics and packet capture

Primary files:

- `PulseLoop/Diagnostics/DiagnosticsExporter.swift`
- `PulseLoop/Diagnostics/RawPacketCapture.swift`
- `PulseLoop/Diagnostics/LogCapture.swift`

Recommended workflow:

1. Reproduce with diagnostics capture enabled.
2. Export diagnostics package.
3. Verify outbound and inbound packets against expected protocol sequence.
4. Correlate decoded event kind and persistence output.

Status: source-confirmed

## Recommended process for validating a new ring

1. Capture advertisement name, service UUIDs, manufacturer data.
2. Verify coordinator and model match.
3. Validate connect/discover/subscribe order.
4. Validate startup command roundtrip.
5. Validate battery + one spot HR + one history sync.
6. Validate find-device/haptic behavior on hardware.
7. Add parser/protocol tests before broad rollout.

Status: source-confirmed

## Licensing and attribution

- Preserve upstream LICENSE and attribution obligations.
- Reverse-engineering notes do not eliminate upstream license requirements.

Status: source-confirmed
