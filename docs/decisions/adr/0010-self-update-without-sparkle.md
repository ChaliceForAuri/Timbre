# 0010 — Self-update: verify by code requirement, swap in place, relaunch; no Sparkle

- **Status:** Accepted
- **Date:** 2026-09-24
- **Implements:** [GDR-0013](../gdr/0013-update-check-off-by-default.md), which
  sets the product terms: off by default, one request to our own site,
  carrying nothing.

## Context

GDR-0013 lets Timbre check for updates on narrow terms and rules out
Sparkle. What remained were the mechanics: where the code lives, what makes
a download trustworthy, how a running app replaces itself, and how to test
a path that ends with the process quitting.

## Decision

**Trust comes from the code signature, not the website.** The version file
carries a SHA-256 and a size, and the download must match both — that proves
the file is the one published. But a compromised site could publish a
matching hash for anything, so the unpacked app must also satisfy, with
strict validation of every architecture and all nested code:

```
anchor apple generic and identifier "dev.hugopretorius.Timbre"
and certificate leaf[subject.OU] = "WX9L5M4Y9Q"
and certificate leaf[field.1.2.840.113635.100.6.1.13] exists
and notarized
```

Our identifier, our team, a Developer ID certificate, and Apple's
notarization. Checked with `codesign -R` before it was written into code: the
notarized release passes; the development build and the retired team's build
both fail. Its bundle version must also equal the version file's.

**One host.** The download URL must share scheme and host with the feed —
https to timbre.hugopretorius.dev in the app. A version file pointing
anywhere else is refused.

**Replace, then relaunch.** `FileManager.replaceItemAt` swaps the verified
bundle in over the installed one in a single filesystem operation. A
detached `/bin/sh` waits for our process ID to exit and then `open`s the new
bundle; the path is passed as an argument, never interpolated into the
script. If the swap fails — a read-only Applications folder — the verified
app is moved to Downloads and revealed, rather than lost.

**Only releases update themselves.** A copy that does not itself satisfy the
requirement — any build from Xcode or `install.sh` — can check, but "Install"
opens the download page. Swapping a development build for a release would
change its signing identity under the developer's feet.

**Where it lives.** `SoftwareUpdater` is a second public type in TimbreKit,
beside `DictationController`. Updating is not part of the dictation
pipeline, and folding it into the controller would make that type the app
rather than the pipeline. Pure decisions — version comparison, the host
rule, the daily schedule — are `nonisolated` types with tests. Blocking work
(hashing, `ditto`, signature checks) runs `@concurrent`, off the main actor.

**The session identifies nothing:** ephemeral configuration, no cookies, no
cache, no credential storage, a User-Agent of just "Timbre".

**Testing a path that quits.** `timbre-eval --verify-update` runs everything
but the relaunch — fetch, decide, download, hash, unpack, verify, and with
`--install-over` the swap into a stand-in bundle — against a file:// feed
before a release and the production feed after it.

## Consequences

- Moving from 0.2.0 to 0.3.0 changes the signing team (S3793TJ443 →
  WX9L5M4Y9Q), so that one step resets the Accessibility grant, and 0.2.0
  cannot update itself anyway. Every update after 0.3.0 keeps the grant:
  TCC keys on the designated requirement, which is identifier plus team.
- Changing team again would strand every installed copy: they would refuse
  the new signature. The requirement's team is a commitment.
- The relaunch is the one step no harness covers. It is ten lines, and the
  first real update is its test.
- No delta updates, no staged rollout, no rollback. At half a megabyte a
  full download costs nothing, and the previous zip stays one git revert away.

## Alternatives considered

- **Sparkle:** rejected in GDR-0013 — a dependency, and profile reporting on
  by default.
- **Trust the hash alone:** rejected; it proves integrity against the
  website, not authenticity against an attacker who controls the website.
- **Replace after quitting, from a helper app:** rejected; a second signed
  binary to ship and keep in step, for a swap `replaceItemAt` already does
  atomically.
- **Updater inside `DictationController`:** rejected; see *Where it lives*.
