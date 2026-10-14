# 0021 — The wordmark: the bare bars beside "timbre", stroke 3, with an underlined secondary

- **Status:** Accepted
- **Date:** 2026-10-14
- **Amends:** [GDR-0019](0019-outfit-and-a-simpler-drawing.md), point 5; [GDR-0017](0017-retro-identity-one-colour-per-gesture.md), point 3 (where the rainbow sits)

## Context

With Nunito chosen (GDR-0020), the wordmark was laid out on the Brand room in every arrangement that was still open: title case and lowercase, the mark tiled and bare, the rounded rainbow under the word, beside it, or absent, and the bars at three weights. Each round narrowed by looking: lowercase first, then the tile dropped beside the word ("if we show the icon with the wordmark we shouldn't show it with a background"), then the doubled rainbow dropped, then the weight.

## Decision

1. **The primary wordmark is the bare bars beside "timbre"**, lowercase, Nunito at its heaviest, no underline. The rainbow appears once in a lockup: in the bars. **The secondary is "timbre" with the rounded rainbow beneath it**, no bars — for the places the tiled icon already stands (an App Store listing, a window with the icon in its title) or where the bars would repeat. Never both rainbows in one lockup.
2. **The bars are drawn at stroke 3 of the 32-unit grid**, up from 2.6, everywhere they appear: the favicon, the app icon, the header, the share image. Heavy enough to sit beside Nunito's extra-bold; light enough that the sixteen-pixel icon keeps its gaps.
3. **The tile stays for the icon alone** — the favicon, the Dock, the update prompt — where a box is wanted. Beside the word the tile would be a second box.
4. **The name in prose stays "Timbre."** Lowercase is the drawing, not the spelling.
5. The rounded rainbow underline keeps its place in the headline, under one word, and the stripe keeps its places between sections. The primary wordmark does not carry it; the secondary is where it belongs.

## Consequences

- One lockup, drawn once (`Mark.svelte` with `tile={false}`), used by the site header and footer, the Backstage sidebar, the login card and the share image. The secondary is the same word with the `rainbow` bar beneath; the Brand room shows both.
- The app icon set and the favicon are regenerated from the same stroke; `tools/app-icon.swift` and `tools/og-image.swift` carry the number.
- The Brand room keeps every round so the next question starts from the comparison.
