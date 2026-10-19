# 0025 — The lockup says how it is said: /tam·br/ beside the word

- **Status:** Accepted
- **Date:** 2026-10-19
- **Amends:** [GDR-0021](0021-the-wordmark.md), point 1
- **Builds on:** [GDR-0017](0017-retro-identity-one-colour-per-gesture.md), point 4 (the mono is for labels); [GDR-0022](0022-nunito-sans-for-text.md)

## Context

Almost nobody says "timbre" right the first time — it looks like "timber" and is said "tam-ber" — and a name you are unsure how to say is a name you do not say aloud, recommend, or search for. Hugo asked for the pronunciation to be part of the logo: "/ tam·br /", a plain respelling between the slashes a dictionary uses, not IPA.

Four settings of that respelling went on the Brand room's "Said aloud" section: beside the word with spaces inside the slashes, beside and tight, beside with no slashes, and beneath the word. Each at card size, the beside ones at header size on both grounds, the first on the live header so the comparison was against the real thing. The choice was made by looking, the same day.

## Decision

1. **The primary lockup is the bare bars, "timbre", and `/tam·br/`**, in that order on one line. The respelling is the lockup's third part, not a caption: wherever the primary wordmark goes, it goes.
2. **The respelling is set in the label mono** (IBM Plex Mono, GDR-0017's face for labels and anything measured), tight inside its slashes, muted, on the word's baseline at half the word's size, and never wrapped. The slashes stay: without them it reads as a second word.
3. **It is hidden from screen readers.** They already say the word correctly, and would read the slashes aloud. The accessible name of the lockup is still "Timbre".
4. **Where a lockup already carries a second line, or is too small to carry a third part, the respelling is left out** — the Backstage sidebar, with "backstage" beneath the word, is the first case. The secondary wordmark (GDR-0021's underlined word) does not carry it either; the share image keeps the secondary.
5. **The spelling of the respelling is "tam·br"**, with the middle dot between the syllables. Not "tam-ber", not IPA: it is a nudge, not a transcription.

## Consequences

- `Wordmark.svelte` is the lockup, drawn once with the respelling as its default; the header, footer and login card use it. GDR-0021's "one lockup, drawn once" now means this component, not `Mark.svelte` beside a typed word.
- The Brand room keeps all four settings with the tight one marked in use, so the next question about the lockup starts from the comparison.
- The app does not show the wordmark anywhere yet. When it does, it uses the same three parts.
