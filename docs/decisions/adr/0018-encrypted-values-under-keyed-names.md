# 0018 — The Library's records: every field an encrypted value, every name a keyed hash

- **Status:** Accepted
- **Date:** 2026-11-13
- **Supersedes in part:** the plain fields and the id-as-record-name of
  [ADR-0017](0017-the-librarys-cloudkit-schema.md). Its zone, its record
  types, events as immutable records, entries by latest edit and the
  never-rename rule all stand.
- **Builds on:** [GDR-0031](../gdr/0031-sync-encryption-before-it-ships.md)
  (decision 2, which this record carries out),
  [GDR-0010](../gdr/0010-optional-icloud-sync-of-personal-dictionary.md),
  [ADR-0015](0015-a-package-per-framework.md).

## Context

GDR-0031 found that the sync was not end-to-end encrypted even with Advanced
Data Protection on: ADR-0017 wrote every field plain, and named each record
by its id, which carries the term (`word:ephemeral`). It required both to be
fixed before the first user's zone exists, because the schema is forever.

The fields are the easy half: CloudKit end-to-end encrypts what is written
through `CKRecord.encryptedValues`. The names are the hard half. A record
name is never encrypted, and it must be the same on every device, or the
same event sent from two devices becomes two records. A plain hash of the id
meets the letter of GDR-0031 and not its point: anyone holding the names can
hash a dictionary and learn which common words are in the Library.

## Decision

1. **Every field is an encrypted value.** Event, Entry and Profile records
   write and read all their fields through `encryptedValues`. No record has
   a plain field. The sync engine fetches whole zone changes, so nothing
   needs to be queryable. A test fails if a plain field appears.
2. **A record is named by HMAC-SHA256 of its id under a 256-bit key**, in
   hex. Same id, same key, same name: the union of events and the
   latest-edit rule work as before. Without the key a name says nothing.
3. **The key lives in the zone, as an encrypted value**, in one record of
   type `Key` named `key`. The names are therefore exactly as private as the
   fields: end to end under Advanced Data Protection, under Apple's keys
   without it.
4. **The key is agreed before anything else is sent.** A device fetches
   first and adopts a key it finds. Finding none, it offers its own. The
   key's record name is fixed, so when two devices offer at once the first
   save wins and the other's fails with the winner's record attached; the
   loser adopts it. Until its key is confirmed a device queues no other
   record. A device that ever adopts a different key forgets what it
   believed the server held and sends it again under the right names.
5. **The local state file changes shape** (`schema: 2`): it knows records by
   name, not id, and holds the key. A file of the old shape is not read; the
   sync starts again from nothing, which costs one full fetch.
6. **CryptoKit joins TimbreCloud.** The key and the HMAC are Apple's; nothing
   is hand-rolled. It is used only for naming, so it stays in this package
   rather than getting one of its own (ADR-0015).

## What stays visible

To Apple, with or without Advanced Data Protection: that the zone exists,
how many records of each type it holds, their sizes, and when each was
created and changed. That is the shape of a Library, not its words. The
data inventory says so.

## Consequences

- GDR-0031's decision 3 is still open. The copy keeps saying "not yet
  end-to-end encrypted" until a record is read back from a real zone with
  the server-side view showing ciphertext; that measurement needs two
  signed-in devices and is recorded when it is made.
- A development zone written before this record holds plain records under
  plain names. They no longer parse and are ignored, but they stay on the
  server: reset the development environment in the CloudKit console before
  the proof.
- Losing the key record loses nothing: every device holds the whole Library
  and the key, and re-sends.
- Deleting the user's data from iCloud (inventory gap 1) is deleting the
  zone, key included.

## Alternatives considered

- **A plain SHA-256 of the id.** Rejected: open to a dictionary attack, so
  the honest copy would have to say that word membership leaks.
- **The key in iCloud Keychain.** Rejected: a second sync system with its
  own timing, no first-writer-wins rule for two devices starting at once,
  and one more place the user's data lives.
- **Random record names.** Rejected: the same event arriving from two
  devices, or from a reinstalled one, would no longer be one record.
- **One encrypted blob per record.** Rejected: ADR-0017's additive fields
  are how the schema grows without a migration.
