# 0022 — Nunito Sans for text; Nunito keeps the headlines

- **Status:** Accepted
- **Date:** 2026-10-14
- **Amends:** [GDR-0020](0020-nunito.md), point 1

## Context

Nunito everywhere was friendly and, at paragraph size, a little tiring: rounded terminals on every letter of a long line. Six pairings went on the Brand room, Nunito over a text face each, with the wordmark, a headline, a paragraph and a button. Nunito Sans was chosen, with Inter named as also good.

## Decision

1. **Headlines and the wordmark stay Nunito**, at its heaviest, as GDR-0020 and GDR-0021 have it. They are `--font-display`.
2. **Text is Nunito Sans**: regular for paragraphs, semibold for emphasis and buttons. It was drawn as Nunito's companion — the same proportions, square terminals — so the two read as one voice at two sizes. It is `--font-sans`.
3. **Inter is the recorded runner-up.** If Nunito Sans ever reads wrong, Inter is the next thing tried, not another round.
4. Both are served by the site, under the OFL, like everything else in `web/static/fonts`.

## Consequences

- Two faces, one family, no decorative third. Labels stay IBM Plex Mono.
- The Brand room marks the pairing in use and keeps the other five.
