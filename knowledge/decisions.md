# iOS Architecture Decisions

Only decisions already visible in source/docs are listed.

## 2026-07-xx — Keep family-specific protocol engines, avoid one-size BLE abstraction

Context:

Rings with similar UI behavior have materially different framing, sequencing, and history semantics.

Decision:

Retain coordinator + driver + sync-engine separation by family.

Reasoning:

Limits cross-family regressions and keeps protocol quirks explicit.

Consequences:

New device onboarding usually means family mapping updates and focused parser/sync tests, not generic rewrites.

Status: source-confirmed

## 2026-07-xx — Spot measurement reconciliation aligns with ring-owned history where applicable

Context:

Certain families log spot results into ring history, which can diverge from app provisional rows.

Decision:

Use reconciliation logic that can prefer ring-owned historical sample when protocol semantics indicate that path.

Reasoning:

Reduces duplicate/conflicting values and aligns persisted truth with device replay behavior.

Consequences:

Deletion/tombstone and reconciliation logic remain tightly coupled to protocol behavior.

Status: source-confirmed

## 2026-07-xx — Preserve decoded-event evidence in diagnostics pipeline

Context:

BLE investigations depend on packet-level evidence with family-specific decoding context.

Decision:

Maintain diagnostics export with raw packet traces and decoded kind metadata.

Reasoning:

Enables source-grounded protocol debugging without requiring speculative reasoning.

Consequences:

Masking/redaction policy must be reviewed whenever new physiological payload decoders are added.

Status: source-confirmed

## Template for future entries

### YYYY-MM-DD — Decision title

Context:

Decision:

Reasoning:

Consequences:
