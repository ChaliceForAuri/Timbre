# 0007 — The hotkey event path stays out of the concurrency runtime

- **Status:** Accepted
- **Date:** 2026-08-19

## Context

Spoke crashed three times in one day — SIGBUS, byte-identical stacks — and
only in Release builds:

```
closure #1 in HotkeyMonitor.start()
  swift_task_isCurrentExecutorWithFlagsImpl
    SerialExecutorRef::isMainExecutor()
      swift_getObjectType            ← EXC_BAD_ACCESS
```

Under ADR-0001's defaults (MainActor isolation everywhere), the closures
handed to `NSEvent.addGlobalMonitorForEvents` inherited `@MainActor`. Swift
therefore compiled a **dynamic executor check** into every monitor callback.
Inside AppKit's Carbon-era event dispatch (`HIToolbox → GlobalObserverHandler`),
that check dereferenced a stale executor pointer and crashed. Debug builds
(-Onone) never hit it; the app ran for days before the optimized build made
it visible.

The deeper point: the check was pure overhead. AppKit delivers these events
on the main thread; the closure body needed no isolation at all — it reads
two primitives off the event and yields to an `AsyncStream` continuation,
which is documented thread-safe.

## Decision

`HotkeyMonitor`'s event handling runs with **no actor isolation and no
dynamic isolation checks**:

- The monitor closures are explicitly `@Sendable`, which opts them out of
  inheriting MainActor isolation — no executor check is emitted.
- They capture exactly two values, both `Sendable`: the stream continuation
  and the `HoldDetector` state wrapped in `OSAllocatedUnfairLock`. They never
  capture `self`.
- All isolation-requiring work (starting dictation, UI) stays downstream,
  where `DictationController` consumes the stream from a single task.

This is an *addition* to ADR-0001's rule that concurrency is opted into
explicitly, not an exception: `nonisolated` + a lock is one of the sanctioned
opt-ins, chosen here because the alternative machinery crashed.

## Consequences

- No executor bookkeeping runs during event dispatch — nothing left to crash,
  and the hot path is cheaper besides.
- `MainActor.assumeIsolated` in these callbacks would reintroduce the same
  runtime machinery (it performs the same class of check); do not "simplify"
  back to it. That is precisely the refactor this record exists to stop.
- The crash itself is timing-dependent and could not be reproduced on
  demand, so there is no regression test. The protection is structural — the
  crashing instruction sequence is no longer emitted — plus this record.
- If Apple's runtime later makes executor checks safe in this context, this
  still costs nothing: the lock is uncontended and the code is simpler than
  the isolation dance it replaced.
