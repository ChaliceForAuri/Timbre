# 0017 — A retro identity: keycap grey, and one colour per gesture

- **Status:** Accepted
- **Date:** 2026-09-25
- **Builds on:** [GDR-0009](0009-renamed-to-timbre.md) (the name), [GDR-0012](0012-command-mode.md) and [GDR-0016](0016-todos-by-voice-into-reminders.md) (the gestures the colours name), [GDR-0013](0013-update-check-off-by-default.md) (the asterisk the headline keeps)

## Context

Timbre's first identity was cool paper and a petrol accent: tasteful, and indistinguishable from every other utility with a Tailwind template. Hugo asked for the opposite for launch — "seriously retro, like NuPhy's keyboard branding: the grey, and then the bright retro colours" — and for a Backstage rebuilt as the place the product is run from, not a lab shell.

The product's own shape suggests the system. Timbre *is* three keys. A keyboard's retro look comes from grey plastic with a handful of coloured caps, and Timbre has exactly a handful of things a key can do.

## Decision

1. **The ground is keycap grey; the ink is charcoal.** Warm neutrals (`oklch` hue 80, near-zero chroma) in both appearances. Buttons are ink on paper, like a legend. No petrol, no blue "primary".
2. **Colour arrives only as the six retro accents**, and each gesture owns one, everywhere it appears — site, Backstage, disk image, share image, and the overlay when it is next touched:
   - dictate (hold right ⌥) — mint green
   - read (tap left ⌥) — mustard yellow
   - command (hold right ⌘ on a selection) — orange
   - to-do (hold right ⌘ with nothing selected) — sky blue
   - explanation card — lilac
   - refusal, error, "must drop" — coral red
   Backstage's rooms take the same six in order, so the rail reads as the rainbow.
3. **The rainbow stripe is the one flourish**: six hard-edged bands under the wordmark, between sections, and under one word of the headline. Never a gradient.
4. **Type is one family with a width axis** (Archivo): the condensed heavy cut for headlines, the regular cut for text, and a mono for labels and anything measured. Headlines are set tight, like printed legends.
5. **Illustrations are drawn, not photographed**: keycaps and the keyboard in CSS, the share image and disk-image background in code (`tools/og-image.swift`, `tools/dmg-background.swift`), so every asset takes the palette from one place and none goes stale.
6. **The claims stay falsifiable.** The headline keeps its asterisk and the asterisk keeps leading to `/network` (GDR-0013). A redesign changes how the page looks, never what it promises.

## Consequences

- One palette file (`web/src/app.css`) and one gesture→colour table are the source of truth. A new gesture gets a colour from the six or it does not get one; a seventh colour is a decision, not a tweak.
- The app's overlay does not yet use the accents (it tints by mode in the site's mock only). When it does, it uses this table, so the pill on the site and the pill on screen match.
- Backstage's pages carry their room's colour on cards and stat tiles; `shadcn` stays the component system and takes only the greys, which is what keeps it from fighting the accents.
- The old petrol appears nowhere. `docs/design/backstage.md` §2 still names the stack; its look is superseded by this record.
