# 0019 — Outfit, served by the site; the keyboard goes; keys are flat

- **Status:** Accepted
- **Date:** 2026-10-13
- **Amends:** [GDR-0017](0017-retro-identity-one-colour-per-gesture.md), points 4 and 5

## Context

Two weeks with GDR-0017 on the live site. The colours, the mark and the clean window-and-pill demo held up; Hugo named them as what he loves. Three things did not: the condensed heavy headline cut read as the thing he disliked most, the drawn keyboard under the demo was busy and "less ugly" was the brief, and the big two-tone keycaps with a legend, a name and a caption had "too much going on". The underline beneath the logotype went the same way.

Six typefaces were laid out side by side in Backstage's Brand room — the mark, the word, a headline and a line of text in each — and the choice was made by looking.

## Decision

1. **Outfit is the typeface**, one family for headlines and text, bold for headlines set a touch tight, regular for text. IBM Plex Mono stays for labels and anything measured. GDR-0017's width-axis family is withdrawn.
2. **The site serves its own fonts.** Both families ship from `web/static/fonts` under the SIL Open Font License; a visit to the site makes no request to Google. The share image is drawn with the same Outfit file the site serves.
3. **The keyboard illustration is withdrawn.** The hero is the window and the pill; nothing underneath.
4. **A key is one flat face, its symbol, a three-pixel edge, and the gesture as a caption beneath.** No legend inside the cap, no bevel, no animation.
5. **The logotype is the mark beside the word "Timbre"**, no underline. The rainbow keeps its three places: the stripe between sections, under one word of the headline, and in the mark.

## Consequences

- Everything in GDR-0017 that is not points 4 and 5 stands: the greys, the six accents and their meanings, the stripe, drawn assets from one palette, the falsifiable claim.
- The Brand room records the candidates and marks the one in use; the next typeface question starts there, not in a chat.
- `tools/og-image.swift` registers the repo's Outfit file for its process, so the card and the page match without the font being installed on the machine.
