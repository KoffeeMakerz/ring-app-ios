# iOS BLE Protocols

This file summarizes iOS family protocol implementations and packet handling.

## Family overview

- jring — `Status: source-confirmed`
- YCBT — `Status: source-confirmed`
- Colmi/QRing — `Status: source-confirmed`
- CRP (Moyoung/Da Rings) — `Status: source-confirmed`
- LuckRing — `Status: source-confirmed`
- RWfit (Legacy + JieLi) — `Status: source-confirmed`

## Discovery and coordinator matching

Primary paths:

- `PulseLoop/RingProtocol/RingBLEClient.swift`
- `PulseLoop/Wearables/WearableCoordinator.swift`
- `PulseLoop/Wearables/WearableModel.swift`

Matching uses advertisement name, service UUIDs, and manufacturer payload hints in coordinator order.

Status: source-confirmed

## CRP protocol

Files:

- `PulseLoop/RingProtocol/CRPProtocol.swift`
- `PulseLoop/RingProtocol/CRPDriver.swift`
- `PulseLoop/RingProtocol/CRPDecoder.swift`
- `PulseLoop/RingProtocol/CRPSyncEngine.swift`

GATT topology:

- Service `fdda`
- Write `fdd2`
- Notify channels include `fdd3` for framed command replies

Frame structure:

- Header `FD DA 10`
- Length field + group + cmd + payload
- Multi-notification reassembly required in decoder path

Representative command groups:

- Group 1: spot measurement and monitor controls
- Group 2: historical timing data queries
- Group 3: device/firmware/wear-state queries
- Group 9: find-device action

Status: source-confirmed

## Colmi/QRing protocol

Files:

- `PulseLoop/RingProtocol/ColmiProtocol.swift`
- `PulseLoop/RingProtocol/ColmiDriver.swift`
- `PulseLoop/RingProtocol/ColmiDecoder.swift`
- `PulseLoop/RingProtocol/ColmiSyncEngine.swift`

GATT topology:

- QRing service variants (`6e40fff0` and `de5bf728` family)
- UART-like write/notify channels

Frame structure:

- 16-byte packet blocks
- payload content + checksum byte

Key command families:

- time, battery, spot measures, telemetry events, big-data history queries

Status: source-confirmed

## YCBT protocol

Files:

- `PulseLoop/RingProtocol/YCBTProtocol.swift`
- `PulseLoop/RingProtocol/YCBTDriver.swift`
- `PulseLoop/RingProtocol/YCBTDecoder.swift`
- `PulseLoop/RingProtocol/YCBTSyncEngine.swift`

GATT topology:

- Service `be940000-7333-be46-b7ae-689e71722bd5`
- Command channel `...0001`
- Stream/history channel `...0003`

Frame structure:

- type + command + total length (LE) + payload + CRC16/CCITT-FALSE

Key semantics:

- capability bitmap query controls available features
- explicit measurement completion verdict affects settle behavior

Status: source-confirmed

## jring protocol

Files:

- `PulseLoop/RingProtocol/JringDriver.swift`
- `PulseLoop/RingProtocol/JringHistorySync.swift`

Highlights:

- history request day-offset semantics are critical
- one-day-at-a-time history sequencing with settle windows in sync helper

Status: source-confirmed

## LuckRing protocol

Files:

- `PulseLoop/RingProtocol/LuckRingProtocol.swift`
- `PulseLoop/RingProtocol/LuckRingDriver.swift`
- `PulseLoop/RingProtocol/LuckRingEncoder.swift`
- `PulseLoop/RingProtocol/LuckRingDecoder.swift`

Highlights:

- family-specific chunking and data-type command model
- explicit pairing completion and find-device command paths

Status: source-confirmed

## RWfit protocol

Files:

- `PulseLoop/RingProtocol/RWfitProtocol.swift`
- `PulseLoop/RingProtocol/RWfitDriver.swift`
- `PulseLoop/RingProtocol/RWfitEncoder.swift`
- `PulseLoop/RingProtocol/RWfitDecoder.swift`

Highlights:

- dual framing variants (legacy and JieLi)
- service-based variant routing at runtime

Status: source-confirmed

## Cross-platform notes

- Family coverage is aligned with Android.
- iOS does not need Android advertisement manufacturer-data reconstruction logic.
- Protocol byte semantics should be ported carefully without assuming equivalent platform transport behavior.

Status: source-confirmed
