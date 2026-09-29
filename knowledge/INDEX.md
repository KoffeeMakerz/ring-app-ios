# PulseLoop iOS Knowledge Index

Read this file first.

## Where to look

- Architecture and state flow: `knowledge/architecture.md`
- BLE protocols and packet formats: `knowledge/ble-protocols.md`
- Sensor paths (spot/live/history): `knowledge/sensors.md`
- Find Device and vibration paths: `knowledge/haptics.md`
- Device capability matrix: `knowledge/devices.md`
- Build/test/debug workflows: `knowledge/testing.md`
- Established decisions: `knowledge/decisions.md`
- High-value protocol discoveries: `knowledge/discoveries.md`

## Certainty labels

- `Status: source-confirmed` — directly supported by repository source.
- `Status: hardware-verified` — explicit real-device evidence exists in repo docs/captures.
- `Status: unverified` — plausible in source, but not confirmed on hardware.

## Highest-priority unknowns

1. Family-by-family confirmation of ring-side vibration semantics (Find Device vs reminder behavior).
2. RWfit variant and capability realization across hardware revisions (Legacy vs JieLi framing behavior).
3. CRP R100 stress availability consistency across firmware batches.
4. Whether any family supports tunable haptic intensity/duration/repeat through currently unused opcodes.
5. Firmware-level differences that can invalidate static capability assumptions.

## Fast orientation files

- BLE lifecycle: `PulseLoop/RingProtocol/RingBLEClient.swift`
- Sync orchestration: `PulseLoop/Services/RingSyncCoordinator.swift`
- Coordinator contracts: `PulseLoop/Wearables/WearableCoordinator.swift`
- Family protocols: `PulseLoop/RingProtocol/*Protocol.swift`
- Family decoders: `PulseLoop/RingProtocol/*Decoder.swift`
- Diagnostics export/capture: `PulseLoop/Diagnostics/DiagnosticsExporter.swift`, `PulseLoop/Diagnostics/RawPacketCapture.swift`
