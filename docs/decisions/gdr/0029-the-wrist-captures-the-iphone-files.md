# 0029 — The wrist captures a to-do; the iPhone files it

- **Status:** Accepted (implementation pending)
- **Date:** 2026-10-18
- **Supersedes in part:** the to-do clause of
  [GDR-0026](0026-apple-watch-the-wrist-key.md) — "this works with no phone
  in range and no model: the detector is Foundation and the store is
  EventKit, both on the Watch". Everything else in GDR-0026 stands.
- **Builds on:** [GDR-0016](0016-todos-by-voice-into-reminders.md),
  [ADR-0015](../adr/0015-a-package-per-framework.md).

## Context

GDR-0026 said the Watch could file a to-do in Reminders by itself, because
EventKit is in the watchOS SDK. It is — and it is read-only there. The
first build against the SDK stopped on `saveReminder` and `saveCalendar`,
which the header marks `__WATCHOS_PROHIBITED`, along with every other write.
Requesting access, listing the lists and fetching open reminders are
allowed. Apple's own Reminders app on the Watch writes through a channel
third parties do not have.

The record checked that a framework existed, not what it allowed. That is
the lesson, and it is in University module 14 now.

## Decision

**The Watch captures and parses the to-do; the iPhone files it.** The date
is still read on the wrist by the same deterministic detector (GDR-0016).
The to-do is queued on the Watch and handed to the iPhone over
WatchConnectivity — `transferUserInfo`, which the system delivers when the
phone is reachable, launching the iPhone app in the background if need be —
and the iPhone saves it to the Timbre list and replies. A to-do said in a
tunnel is not lost, only late; the Watch shows how many are waiting.

- **The wrist still reads the list back**, through EventKit, which the
  Watch allows. "Read my list" needs no phone.
- **WatchConnectivity is a new framework, so it is a new package**
  (ADR-0015): `TimbreReminders` gains nothing; `TimbreRelay` holds the
  queue, the message shape and the session, for iOS and watchOS only. The
  queue and the messages are pure and tested; the session is not.
- **No network request from any binary, still.** WatchConnectivity is
  Apple's transport between the user's own devices, the shape GDR-0010 and
  GDR-0026 already reason from.
- **The Action Button's intent captures the same way**: it parses and
  queues; the dialog says the to-do is on its way through the iPhone.

## Consequences

- The to-do key on the wrist is capture, not filing. The copy says so:
  *on its way to Reminders through your iPhone*. When the phone confirms,
  the Watch shows the confirmation and plays the success haptic; until
  then, a click.
- `ReminderStore.canAdd` is false on watchOS and `add(_:)` does not exist
  there, so a Watch build cannot call it by mistake.
- The iPhone app files to-dos it did not hear, on behalf of the Watch; the
  Reminders permission is asked for on the phone the first time.
- GDR-0026's index entry notes the superseded clause. The record itself
  stays, reasoning and mistake included.

## Alternatives considered

- **A Timbre list of its own on the Watch, synced through the Library:**
  rejected; GDR-0016 chose Reminders because it is on every device, and a
  second list is the thing it rejected.
- **Keep the to-do on the Watch until the user opens the iPhone app:**
  rejected; `transferUserInfo` reaches a closed app, so there is no reason
  to make the user do anything.
- **Reminders' Shortcuts action from the Watch:** rejected; one app cannot
  run another's intent.
