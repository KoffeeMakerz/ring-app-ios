# iOS Sensor Paths

This file maps measurement control and persistence paths in iOS source.

## Shared event pipeline

1. Sync coordinator requests a measurement/history action.
2. Driver/decoder emits typed decoded events.
3. Event bridge publishes bus events.
4. Persistence subscriber writes measurements and summaries.

Core paths:

- `PulseLoop/Services/RingSyncCoordinator.swift`
- `PulseLoop/RingProtocol/*Decoder.swift`
- `PulseLoop/Events/PulseEventBus.swift`

Status: source-confirmed

## Heart rate (HR)

Start/stop:

- Triggered from `RingSyncCoordinator` measurement methods.
- Family sync engines send protocol-specific start/stop commands.

Realtime/history:

- Spot and workout paths consume live samples.
- History samples arrive via family history flows and are persisted separately.

Status: source-confirmed

## HRV

- Available in selected families via spot and/or history timing frames.
- Often consumed as historical/timing data rather than continuous live stream.

Status: source-confirmed

## SpO2

- Spot mode for supporting families.
- History/all-day availability depends on family and firmware behavior.

Status: source-confirmed

## Stress

- Real stress values consumed where available.
- Derived stress fallback from HRV exists for devices/rings that provide no real stress values.

Status: source-confirmed

## Temperature

- Spot and historical timing flows exist in supported families.
- CRP/YCBT timing history parsing handles frame pagination and slot conversion.

Status: source-confirmed

## Sleep

- Family sleep frames decode to staged records.
- Persistence merges/reconciles sessions with de-duplication safeguards.

Status: source-confirmed

## Steps and activity

- Realtime and history flows coexist.
- Persisted activity rows are maintained with safeguards against sync-side duplication artifacts.

Status: source-confirmed

## Battery

- Family-dependent battery updates from GATT or in-protocol notifications/queries.
- Persisted for trend and alert features.

Status: source-confirmed

## Raw PPG and raw accelerometer

- No stable app-level raw PPG or raw accelerometer ingestion path is exposed as a first-class persisted metric.

Status: unverified

## Sensor differences vs Android

- Family intent and coverage are largely aligned.
- Platform lifecycle differences (CoreBluetooth vs Android Bluetooth stack) can alter practical success rates for startup and reconnect-sensitive measurements.

Status: source-confirmed
