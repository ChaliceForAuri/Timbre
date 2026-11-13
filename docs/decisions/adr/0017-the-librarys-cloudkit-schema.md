# 0017 — The Library's CloudKit schema: events as immutable records, entries by latest edit, one zone

- **Status:** Accepted
- **Date:** 2026-10-18
- **Builds on:** [GDR-0023](../gdr/0023-the-library.md) (decision 1: the
  Library syncs through iCloud, behind a sync interface),
  [GDR-0010](../gdr/0010-optional-icloud-sync-of-personal-dictionary.md)
  (off by default, plainly described, never dictations),
  [ADR-0013](0013-timbrecore-platform-neutral-package.md) (`LibrarySync`;
  the merge is the Library's own rule),
  [ADR-0014](0014-strength-from-events-fsrs.md) (events are the record),
  [ADR-0015](0015-a-package-per-framework.md) (a package per framework).
  University module 13 is the long version.

## Context

GDR-0023 chose CloudKit's private database and left the shape to a record
written with the code. A CloudKit schema is forever: once deployed to
production, a record type or field can be added but never renamed, retyped
or removed, and every build a user ever ran must still read what a newer
one writes. The Library's own design (ADR-0014) points the way: events are
immutable and only ever added; strength is never stored; entries are
edited rarely; the profile is small.

## Decision

**One custom zone, three record types, every field additive, and the
Library's merge rule doing the merging — never CloudKit's.**

```
Zone "Library" in the private database (custom, so changes can be fetched
by token; the default zone cannot).

Event    recordName = the event's composed id (ADR-0014)
         entry, kind, date, device, app?, drill?
         Immutable: saved once, never modified, never deleted.
Entry    recordName = the entry's id
         kind, term, heard?, meaning?, example?, tags, sourceDevice,
         sourceDate, sourceHow, sourceApp?, edited
         Replaced whole on edit; the later `edited` wins.
Profile  recordName = "profile"
         industries, role?, firstLanguage?
```

- **`CKSyncEngine` carries the records**; `TimbreCloud` is the package
  (CloudKit on all three platforms). It keeps a small state file beside the
  Library — the engine's serialization, which events and entry edits the
  server has, the server's system fields for each entry — and nothing in it
  is a word.
- **Merge is a union of events, then entries by latest edit** — the
  Library's `merge(entries:events:)`, unchanged. A server-changed conflict
  on an entry is resolved by taking the server's record, merging, and
  sending ours again over the server's system fields.
- **Deletions are events.** No record is ever deleted; a `forgot` event is
  the tombstone, and the merge honours it on every device.
- **The profile is taken from the server only when this device's is
  empty**; otherwise this device's is sent. Two profiles edited apart is a
  case we do not pretend to solve.
- **Off by default; a toggle per device; stopping keeps what is local.**
  The container is `iCloud.dev.hugopretorius.Timbre`, shared by the Mac,
  the iPhone and the Watch regardless of bundle identifier.

## Consequences

- The mapping to and from `CKRecord` is pure and tested offline; the engine
  is not, and the two-device proof the product map asks for — teach on one,
  see it on the other, `nettop` empty — is a manual test on hardware.
- Adding a field is a change to a record type and a default on read; a
  rename is forbidden and the code says so where the fields are named.
- The iCloud entitlements join all three apps. A build without a team runs
  with the toggle off; with a team, Xcode's automatic signing registers the
  container the first time.
- Strength is still never stored, here or anywhere: a device that fetches
  a year of events recomputes it.

## Alternatives considered

- **SwiftData with CloudKit mirroring:** rejected (ADR-0013); it cannot
  express a union of histories.
- **One record per entry holding its history as a list:** rejected; two
  devices appending to one list is the conflict the event design avoids.
- **The key-value store, as GDR-0010 first chose:** rejected; too small,
  whole-value replacement, no per-record merge.
