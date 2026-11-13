# 0031 — The Library's sync is encrypted in transit and at rest today; end-to-end before it ships

- **Status:** Accepted
- **Date:** 2026-10-22
- **Supersedes in part:** the copy clause of
  [GDR-0010](0010-optional-icloud-sync-of-personal-dictionary.md) — "end-to-end
  encrypted when Advanced Data Protection is on" — and the plain-field
  schema of [ADR-0017](../adr/0017-the-librarys-cloudkit-schema.md). Everything
  else in both stands.
- **Builds on:** [GDR-0030](0030-review-here-evidence-on-the-pr.md) (the
  review that found it), [GDR-0006](0006-app-never-phones-home.md).

## Context

GDR-0010 promised that the sync setting would say the Library is end-to-end
encrypted when the user has Advanced Data Protection on, and the Mac, the
iPhone, the site and University module 13 all said so. The first review run
under GDR-0030 checked the claim against the code. Advanced Data Protection
end-to-end encrypts a third-party app's CloudKit data only where the app
stores it as *encrypted values* (`CKRecord.encryptedValues`) or as assets;
plain fields stay under Apple's keys so the server can index them. ADR-0017
writes every field plain, and names both event and entry records by their
composed ids, which carry the term. The claim was not true, and no user has
a zone yet.

## Decision

1. **The copy tells the truth now.** Settings on the Mac and the iPhone, the
   network page, module 13 and the data inventory say *encrypted in transit
   and on Apple's servers; not yet end-to-end encrypted*. GDR-0010's
   honest-copy rule is what this record applies.
2. **End-to-end before sync ships.** Before the toggle is offered in a
   release, the Library's fields are written through `encryptedValues` and
   records are named by an opaque hash of their id, not the id. That is the
   schema change ADR-0017's "forever" rule says must happen before the first
   zone exists; this record is the notice. The sync engine fetches whole
   zone changes, so no field needs to be queryable.
3. **Then the copy changes back**, to GDR-0010's sentence, and the record
   that lands the schema says so with the measurement: a record read back
   from the user's zone with the server-side field view showing ciphertext.

## Consequences

- iCloud sync stays off by default and unshipped until decision 2 is done;
  the toggle in the current builds is for the proof on two Macs, not for
  users.
- Inventory gap 6 is this record's work item; the inventory's §3 row and
  gap 6 are updated when it closes.
- Module 13 teaches the distinction between plain and encrypted fields, so
  the mistake is not made twice.

## Alternatives considered

- **Keep the claim and fix the schema later.** Rejected: a privacy claim that
  is slightly wrong is worse than a bounded one (GDR-0010's honest-copy
  rule), and the first user's zone would have fixed the plain schema forever.
- **Drop the end-to-end goal.** Rejected: for a product whose one promise is
  that nothing leaves the user's control, the sync must not be the exception.
