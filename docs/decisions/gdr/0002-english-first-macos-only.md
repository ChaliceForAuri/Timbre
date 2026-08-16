# 0002 — English-first, macOS-only

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

Wispr Flow markets 100+ languages with code-switching, served by cloud
models. Apple's on-device ASR is materially weaker outside English and has
no real code-switching. On iOS, system dictation cannot be replaced; the
only integration point is a keyboard extension, which is memory-constrained
to the point of ruling out this architecture.

Chasing either gap means fighting the platform instead of leaning on it.

## Decision

Spoke will be **English-first and macOS-only**. Other languages work exactly
as well as Apple's models allow, unadvertised. No iOS app, no keyboard
extension.

## Consequences

- Positioning is honest and simple: the best *local* dictation for the Mac.
- Users who live in two languages are not the audience yet; we say so
  rather than half-serving them.
- If Apple's multilingual models improve, we inherit the improvement for
  free — the locale plumbing already exists in `Transcriber`.
- No iOS revenue or reach; the Mac is where dictation-into-any-app is
  actually possible, so that's where the product is.

## Alternatives considered

- **Bundling whisper.cpp for multilingual:** rejected — violates the
  no-dependencies rule, triples app size, and reintroduces the model-ops
  burden Apple just took off our hands.
- **iOS keyboard extension:** rejected — memory limits preclude the
  pipeline; a degraded companion app would dilute the story.
