# 0014 — Strength is retrievability, derived from an entry's events with FSRS-4.5

- **Status:** Accepted
- **Date:** 2026-10-18
- **Builds on:** [GDR-0023](../gdr/0023-the-library.md) (a strength that
  practice raises and time lowers),
  [GDR-0027](../gdr/0027-word-of-the-day-the-bar.md) (weakest first; met in
  the wild), [ADR-0013](0013-timbrecore-platform-neutral-package.md).
  University module 12 is the long version.

## Context

The Library's entries carry a strength (GDR-0023) and the word of the day
picks the weakest that is due (GDR-0027). Three devices record practice and
meetings, and their copies must agree. Two choices were open: what the
number is, and whether to store it.

The number could be a home-grown score, SM-2's ease and interval, or a
model fitted to how memory actually decays. SM-2 is a fixed recipe with a
known failure mode. FSRS — the Free Spaced Repetition Scheduler, open, now
Anki's optional scheduler — models recall as a probability that falls as a
power law of elapsed time over a per-item stability, and updates stability
and difficulty from each outcome with published parameters.

Storing the number means two devices can disagree about it with no right
answer. Storing the events means the number is a function of them.

## Decision

**Strength is retrievability — the probability of recall right now —
computed by FSRS-4.5 with its published default parameters from the entry's
events, and never stored.**

- **Events are the record:** `taught`, `met`, `passed`, `failed`, `forgot`,
  each with a date to the second, the device, and for a drill which one; for
  `met`, the app and never the sentence. The Library appends; it never edits
  an event.
- **Grades are coarse by design.** A pass or a meeting in the wild is FSRS's
  *good*; a fail is *again*. There is no *hard* or *easy*, because nobody
  grades themselves (University module 12's trap). Teaching an entry is its
  first encounter and starts it where a first *good* would.
- **Due means below 0.9.** Stability is, by definition, the days until
  retrievability falls to that target. A new word is due a few days after it
  is taught; a pass pushes the next return out; a fail is a fresh exposure
  that returns sooner than a fade but not the next morning — `picks.json`
  case 03 records that this is intended.
- **Replay is deterministic and order-independent.** Events are sorted by
  date then id before replay, so every device computes the same state from
  the same set, and a changed parameter recomputes every strength from
  history.
- **Merge is a union** of events by id — composed from the event's fields,
  not hashed — and `forgot` is a tombstone that ends the history until the
  entry is taught again.
- **The day's pick is computed at the start of the day** from the events
  before it, so the word is the same from midnight to midnight on every
  device.

## Consequences

- `Strength` in TimbreCore is a hundred lines, pure, with the weights inline
  and the formulas named as FSRS names them. Changing the version or the
  weights is this record's successor and a replay, never a migration.
- Strength is cheap — a handful of events per entry — and computed on
  demand; nothing caches it.
- The parameters are FSRS's population defaults, not fitted to the user.
  Fitting needs hundreds of reviews and an optimiser, and would be a record
  of its own if the drills ever produce that much history.
- Because `met` counts as *good*, a word used daily is never due. That is the
  intent: it is known.

## Alternatives considered

- **SM-2:** rejected; a fixed recipe, ease hell, and no probability to show
  as a bar.
- **A home-grown score (plus one per pass, minus one per fail):** rejected;
  it says nothing about *when* to ask.
- **Stored strength, synced:** rejected; no right answer on conflict
  (GDR-0023, decision 1).
- **Fitting FSRS to the user now:** deferred; there is no history to fit
  against.
