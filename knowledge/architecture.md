# iOS Architecture

## Application shape

PulseLoop iOS uses a CoreBluetooth client with coordinator/driver/sync-engine layering and event-driven persistence.

Core files:

- BLE orchestration: `PulseLoop/RingProtocol/RingBLEClient.swift`
- Coordinator + model matching: `PulseLoop/Wearables/WearableCoordinator.swift`, `PulseLoop/Wearables/WearableModel.swift`
- Sync orchestration: `PulseLoop/Services/RingSyncCoordinator.swift`
- Event bus: `PulseLoop/Events/PulseEventBus.swift`
- Persistence subscriber: `EventPersistenceSubscriber` in `PulseLoop/Events/PulseEventBus.swift`
- Data models: `PulseLoop/Models/`

Status: source-confirmed

## BLE abstraction layers

`RingBLEClient` responsibilities:

- Scan and discovery
- Coordinator selection and driver installation
- Connect/discover/subscribe sequencing
- Serialized write queue and timeout handling
- Reconnect and restoration behavior

Family behavior is encapsulated in `WearableDriver` + `RingSyncEngine` implementations created by coordinators.

Status: source-confirmed

## Coordinator and device-family mapping

Key family coordinators under `PulseLoop/RingProtocol/`:

- `JringCoordinator.swift`
- `YCBTCoordinator.swift`
- `ColmiCoordinator.swift`
- `ColmiSmartHealthCoordinator.swift`
- `CRPCoordinator.swift`
- `LuckRingCoordinator.swift`
- `RWfitCoordinator.swift`

Coordinator order is behavior-critical for ambiguous advertisements.

Status: source-confirmed

## State flow

Typical flow:

1. Start scan in `RingBLEClient`.
2. Match advertisement to coordinator/model.
3. Connect peripheral and discover services.
4. Enable required notify characteristics.
5. Emit connected state and run startup sync.
6. Decode packets to events and persist to SwiftData-backed stores.

Status: source-confirmed

## Data storage and app integration

- Event persistence consumes bus events and writes device, measurement, battery, activity, and sleep records.
- UI layers read persisted and live state via SwiftUI view models/services.
- Ring controls call into `RingSyncCoordinator` for spot measures, history sync, and find-device operations.

Status: source-confirmed

## Platform dependencies

- CoreBluetooth lifecycle and callbacks.
- Background-central behavior and restoration keys in app configuration.
- Swift concurrency and actor isolation in BLE/event orchestration.

Status: source-confirmed

## Cross-platform differences (iOS vs Android)

- iOS receives manufacturer data in CoreBluetooth advertisement payload format directly; Android requires reconstruction logic.
- iOS does not use Android-style OS bond allowlist flow.
- Reconnect/watchdog details differ by platform APIs, while protocol intent remains aligned.

Status: source-confirmed
