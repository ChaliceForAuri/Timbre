# 0009 — The product is called Timbre

- **Status:** Accepted
- **Date:** 2026-08-21
- **Renames:** the product formerly recorded as "Spoke" in GDR-0001 … GDR-0008
  and ADR-0001 … ADR-0007

## Context

"Spoke" read as bicycle hardware more than speech. A rename was proposed to
"Spoken", which searching immediately disqualified on two counts: **Spoken
Content** is Apple's own name for the macOS text-to-speech feature this app
integrates with — our Settings screen contains the string "Open Spoken
Content settings…" — and **Spokenly** is an existing Mac speech-to-text app.

Checking further candidates turned up a crowded field. **Utter** is a
local-first Mac dictation app. **Cadence** is *three* products, two of them
Mac voice tools, one describing itself as "hold a hotkey and speak" — this
app's exact interaction model. Also found: SpeakMac, BetterDictation,
Dictato, WhisperType, Careless Whisper.

That crowd is itself the finding. "Local, private, hold-a-hotkey dictation"
is not a unique position, so the name has to carry more weight, not less. A
generic name would be actively harmful.

## Decision

The product is **Timbre** — the character that makes a voice recognisably
someone's own. It fits a tool that is private by construction and now speaks
in both directions (GDR-0008).

Verified before committing: no Mac dictation or text-to-speech product uses
it; the nearest uses are an iOS audio/video editor and an Android dating app,
neither in this category; US trademark #1904180 (TIMBRE) has been
dead since 2002. Not a legal clearance — that needs a lawyer, as GDR-0005
already notes for licensing.

Mechanically: bundle identifier `dev.hugopretorius.Timbre`, package
`TimbreKit`, tool `timbre-eval`, repository and domain to match.

### What was deliberately *not* renamed

- **Existing decision records.** CLAUDE.md's rule is that records are
  immutable and superseded rather than edited. ADR-0001 … ADR-0007 and
  GDR-0001 … GDR-0008 still say "Spoke", `SpokeKit`, `spoke-eval`, because
  that is what was true when each decision was made. This record is the
  pointer that translates them.
- **`field-notes.md`** — an append-only lab notebook. Rewriting past
  observations would defeat its purpose.
- **Shipped release notes.** v0.1.0 and v0.1.1 really were called
  `Spoke-0.1.0.zip`. Renaming them in the changelog would describe artifacts
  that never existed.
- **The words "spoke" and "spoken" in English.** `SpokenCommands`,
  `spokenPrefix`, and "the person who spoke" are not the product name. The
  rename script matched only distinctive compound tokens plus `\bSpoke\b`,
  which cannot match "Spoken".

## Consequences

- **Every TCC grant is orphaned.** Changing the bundle identifier makes this
  a new app to macOS: Microphone and Accessibility must be granted again on
  all three machines, and the stale "Spoke" rows removed by hand. This is the
  trap already documented in CLAUDE.md, paid deliberately.
- **Captured dictations do not migrate.** The log moves from
  `~/Library/Application Support/Spoke/` to `…/Timbre/`. Nothing is deleted;
  the old directory simply stops being read.
- The corpus's vocabulary case, which existed because the transcriber heard
  "SpokeKit" as "spell kid", now tests "TimbreKit". Its audio fixture was
  regenerated.
- Renaming cost roughly an hour with two releases shipped and no users. At a
  hundred users it would have cost a migration guide and a support thread;
  this was the cheapest moment it would ever be.
