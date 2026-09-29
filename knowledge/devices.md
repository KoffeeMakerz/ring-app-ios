# iOS Device Capability Matrix

Capabilities below are derived from implemented protocol/coordinator paths and documented evidence.

Legend:

- Yes = implemented/advertised in source
- No = not implemented in source
- ? = uncertain or hardware-dependent

## Family matrix

| Family | Connect | Battery | HR | HRV | PPG Raw | ACC Raw | SpO2 | Stress | Sleep | Find Device | Alarms/Reminders | Vibration | Custom Vibration |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| jring | Yes | Yes | Yes | ? | No | No | Yes | No | Yes | Yes | ? | ? | ? |
| YCBT/TK5/R10M/SmartHealth | Yes | Yes | Yes | Yes | No | No | Yes | Yes | Yes | Yes | Yes | ? | ? |
| Colmi/QRing | Yes | Yes | Yes | Yes | No | No | Yes (model-dependent) | Yes (model-dependent) | Yes | Yes | Yes | ? | ? |
| CRP (R11/R100) | Yes | Yes | Yes | Yes | No | No | Yes (device-dependent) | ? | Yes | Yes | ? | ? | ? |
| LuckRing | Yes | Yes | Yes | Yes | No | No | Yes | Yes | Yes | Yes | ? | ? | ? |
| RWfit | Yes | Yes | Yes | ? | No | No | Yes | No | Yes | No | ? | ? | ? |

## Certainty notes

- Coverage above reflects source-implemented capabilities: `Status: source-confirmed`
- Family/model runtime differences (especially stress/SpO2) remain firmware-dependent: `Status: unverified`
- CRP R100 stress absence in documented captures: `Status: hardware-verified`

## Cross-platform note

- Family support is broadly aligned with Android, but Android-specific bond policy and advertisement normalization can change practical outcomes.
