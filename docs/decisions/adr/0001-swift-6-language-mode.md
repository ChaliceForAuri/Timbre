# 0001 — Swift 6 language mode with default MainActor isolation

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

The planning-phase code was written without a compiler and recommended Swift 5
language mode "while learning", on the premise that strict concurrency rejects
passing `AVAudioPCMBuffer` across actor boundaries and that fighting it would
slow us down.

That premise is false for this codebase. Apple ships
`AnalyzerInput: @unchecked Sendable` precisely so audio can cross isolation
boundaries safely — the intended design is to convert the buffer on the audio
thread and hand the analyzer an `AnalyzerInput`, not to pass raw buffers
around. Every place the code would have fought the checker is a place the
architecture was wrong, not the checker.

Xcode 26's own app template enables Swift 6 mode with "approachable
concurrency" (default MainActor isolation, SE-0466; `nonisolated(nonsending)`
by default, SE-0461). That is the current Apple standard for new app code.

## Decision

We will use **Swift 6 language mode with complete concurrency checking**
everywhere, from the first commit that compiles:

- `SwiftSetting.defaultIsolation(MainActor.self)` in SpokeKit — app-adjacent
  code is MainActor by default; concurrency is opted *into* (`actor`,
  `nonisolated`), not out of.
- Upcoming features `NonisolatedNonsendingByDefault` and
  `InferIsolatedConformances` enabled, matching the Xcode 26 template.
- No `@unchecked Sendable` in our own code without a comment proving the
  invariant that makes it safe.

## Consequences

- Data races are compile errors, not field bugs. In an app whose core loop is
  an audio thread, an actor, and the main actor, this is worth real money.
- The audio path must be architected correctly (conversion on the audio
  thread, `AnalyzerInput` across the boundary) rather than patched with
  escape hatches. This is more design work up front.
- Learning cost is front-loaded: the compiler teaches isolation now instead
  of a crash teaching it later.
- We track Apple's current template defaults, so future Xcode migrations are
  small.

## Alternatives considered

- **Swift 5 mode while learning (the SETUP.md plan):** rejected — its
  motivating example is solved by the SDK, and unlearning warnings-as-noise
  is harder than learning errors-as-teacher.
- **Swift 6 mode without default MainActor isolation:** rejected — sprays
  `@MainActor` annotations over every type; the default expresses the truth
  of this codebase more quietly.
