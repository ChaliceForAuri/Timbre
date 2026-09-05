# 0010 — Optional iCloud sync of the personal dictionary

- **Status:** Accepted (implementation pending)
- **Date:** 2026-08-24
- **Amends:** the "no sync" clause of [GDR-0001](0001-local-only-free-no-account.md).
  Everything else in GDR-0001 stands.

## Context

Timbre is growing a personal dictionary: words the user has taught it, and
soon acronyms with their expansions. Hugo runs Timbre on three Macs, and a
dictionary taught on one is invisible to the other two. Teaching the same
word three times is exactly the friction a personal tool should not have.

GDR-0001 said *"No sync — deliberate, it's the privacy story."* That was
right when the only data was dictations. The dictionary is a different class:
small, explicitly authored by the user, and useful precisely because it
travels.

Two promises are in tension and must be kept apart:

1. **"The app makes zero network requests"** — the falsifiable, Little
   Snitch–checkable claim (GDR-0006).
2. **"Dictation that never leaves your Mac"** — the landing page headline.

iCloud keeps (1) literally: `NSUbiquitousKeyValueStore` writes to a local
container and macOS system daemons perform the sync. The Timbre binary still
opens no sockets. iCloud breaks (2) as worded: the dictionary would sit on
Apple's servers.

## Decision

Timbre may sync the **personal dictionary only** — taught vocabulary and
acronym expansions — through the user's own iCloud, via
`NSUbiquitousKeyValueStore`. Subject to all of:

- **Off by default.** The default install still leaves nothing off the Mac.
- **Plainly described** in Settings, including that it uses the user's own
  iCloud account and is end-to-end encrypted when Advanced Data Protection is
  on. The setting should link to Apple's ADP documentation.
- **Never dictations, transcripts, captures, or timings.** Only the
  dictionary. This is a hard line, not a default.
- **Pure Apple.** No third-party sync service, ever.
- **Honest copy.** When this ships, the headline changes from *"never leaves
  your Mac"* to *"never leaves your devices"*, with the sync explained beside
  it. Until it ships, the current headline remains literally true and stays.
- **Export/import remains** as the path for anyone who declines iCloud.

## Consequences

- GDR-0006's claim — zero network requests from the binary — is untouched.
  System daemons syncing a user's own iCloud is not the app phoning home, and
  the distinction is real: nothing Timbre does can be observed on the wire.
- The `com.apple.developer.ubiquity-kvstore-identifier` entitlement and an
  embedded provisioning profile join `release.sh`. Developer ID apps support
  this; it is signing plumbing, not a distribution change.
- Wispr Flow sends **audio** to its servers. Syncing a word list to the user's
  own encrypted iCloud is categorically different, and the comparison holds up
  in public. The marketing must say exactly what syncs and what never does.
- The dictionary itself is the prerequisite: sync is worth building only once
  taught words reach the transcriber via `SFCustomLanguageModelData`, which is
  the fix for the "spell kid" class of error. Order: dictionary → transcriber →
  command mode → sync.

## Alternatives considered

- **No sync, ever:** rejected. Real friction across three Macs, and the
  privacy gain protects data the user explicitly wants to carry with them.
- **CloudKit database:** rejected as overkill for a word list. KVS is designed
  for exactly this.
- **Local-network peer sync (Bonjour):** rejected — both Macs must be awake,
  and it is far more code for a worse experience.
- **Export/import only:** kept as the fallback, rejected as the primary path.
