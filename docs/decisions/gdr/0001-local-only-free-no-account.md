# 0001 — Local-only, free, no account

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

Spoke exists as an answer to Wispr Flow: $15/month, cloud transcription,
account required. Apple now ships the two components that made the cloud
necessary — streaming on-device ASR (`SpeechAnalyzer`) and an on-device LLM
(`FoundationModels`) — free with the OS on Apple Silicon.

The remaining reasons to run a cloud are telemetry, sync, and billing. Spoke
wants none of them.

## Decision

Spoke will be **free, fully local, and account-less. Nothing the user says
ever leaves the machine.** No network calls, no telemetry, no login, no
subscription. Distribution is direct download (notarized, outside the App
Store — required anyway, see
[ADR-0003](../adr/0003-insertion-via-pasteboard-paste.md)).

This is the product's constitution: any feature that requires a server is
out of scope by definition, not by prioritization.

## Consequences

- Privacy is a *structural guarantee*, not a policy promise — the app can be
  audited to make no network calls. This is the entire marketing story.
- No sync of vocabulary or settings across machines. Framed as a feature.
- No usage analytics; product decisions rely on direct user feedback.
- No revenue. This is a deliberate choice at this stage, not an oversight.
- Quality is capped by Apple's on-device models; we compete on integration
  and taste, not model size.

## Alternatives considered

- **Freemium with a paid cloud tier:** rejected — reintroduces everything
  the product exists to remove.
- **Paid app, still local:** rejected for now — free is the wedge against a
  subscription incumbent; revisit only with evidence.
- **Optional opt-in telemetry:** rejected — "no network calls" must stay
  auditable and absolute to mean anything.
