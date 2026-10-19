# 0024 — The menu bar shows the bare bars, and the bars carry the state

- **Status:** Accepted
- **Date:** 2026-10-19
- **Amends:** [GDR-0021](0021-the-wordmark.md), point 3; [GDR-0017](0017-retro-identity-one-colour-per-gesture.md), point 2
- **Builds on:** [GDR-0013](0013-update-check-off-by-default.md) (nothing appears unless the user comes looking)

## Context

The menu bar item had been Xcode's microphone symbol since the first build, swapping to three unrelated symbols by state: a filled microphone, sparkles, a warning triangle. The icon shipped in 0.4.0, and the one place a user sees Timbre all day still showed nothing of the mark. Hugo asked for the brand icon there, and for it to show the statuses that matter.

The menu bar has rules of its own. Its glyphs are drawn in the bar's ink, inverted under an open menu, and it carries two appearances; a glyph that ignores that looks pasted on. And it is where every app's badge competes for attention.

## Decision

1. **The menu bar item is the bare bars** — the mark without its tile. GDR-0021 keeps the tile for the icon alone, and the menu bar is not that: among the bar's glyphs a tile is a second box.
2. **The one drawing carries the state; no other glyph appears there.** Five looks: the bars dimmed while setting up; in the bar's own ink when ready; in the retro colours while listening; the colours fading while the cleanup runs; every bar coral on an error, the identity's colour for "must stop" (GDR-0017), until the next gesture or the grant that fixes it. The ink states are template images, drawn by the system; the coloured ones are not.
3. **Colour in the menu bar means the microphone is open.** That is the rule a future state has to fit: if the mic is not open, the bars are not lit. The menu bar shows the mark lit, never the gesture's own colour — it cannot tell a dictation from a command hold, and does not need to. The gesture's colour belongs to the pill, where the user is looking.
4. **Nothing badges an update**, or anything else the user has not asked about. No dot, no count. GDR-0013 keeps updates to the menu.
5. **Drawn in code from the favicon's grid**, stroke 3 of 32 units scaled to a 2.5-point stroke, the same numbers `tools/app-icon.swift` draws with. A change to the mark is a change in two places, never a stale PNG.

## Consequences

- `MenuBarIcon` in the app target is the drawing and the state-to-look table. A new `DictationController.Status` case must choose a look there; the switch is exhaustive, so the compiler asks.
- Each look carries an accessibility description ("Timbre: listening"), which is how VoiceOver reads the state.
- When the overlay takes the accents (GDR-0017's open consequence), the menu bar does not repeat them: the pill says which gesture, the bar says the mic is open.
- The fading "cleaning up" look is the one to watch. If it reads as a glitch rather than a mic closing, it drops to the dimmed grey of setting up — a new record's one line, not an edit here.
