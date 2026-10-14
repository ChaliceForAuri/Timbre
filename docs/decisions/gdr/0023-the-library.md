# 0023 — The Library: one store, five kinds, synced by iCloud, practised by voice

- **Status:** Accepted
- **Date:** 2026-10-14
- **Builds on:** [GDR-0001](0001-local-only-free-no-account.md) (the claim), [GDR-0006](0006-app-never-phones-home.md) (the boundary), [GDR-0010](0010-optional-icloud-sync-of-the-personal-dictionary.md) (iCloud for the dictionary), [GDR-0011](0011-taught-corrections-before-the-model.md) and [GDR-0012](0012-command-mode.md) (what the Library replaces and feeds)
- **Decides:** the five questions in `docs/design/product-map.md` §8

## Context

Hugo wants Timbre to make him better at four things: spelling, vocabulary, phrases, acronyms. The product map (2026-10-11) laid out how the product grows to do that — a Library, a phone, sync, practice — and ended with five decisions. They were walked through one at a time on 2026-10-14, each with its alternatives, and taken as follows.

## Decisions

1. **The Library syncs through iCloud, not an account.** CloudKit, private database, the user's own account; Apple's daemons move the data and the binary still makes zero requests. The store is built behind a sync interface so an account backend could be added later. An account becomes a decision on the day a non-Apple Library client is wanted, with its own record and its own change to `/network`. Until then, "Apple pure" is the product, not a tier.
2. **Timbre for iPhone is a companion.** The Library in your pocket: review, practise, word of the day, add a word you heard. It does not dictate into other apps — iOS cannot — and a keyboard extension is not planned. If one is ever wanted it is a record of its own.
3. **One Library, five kinds.** `word`, `acronym`, `phrase`, `spelling`, `correction`, replacing the three Settings lists. Every entry carries its meaning, an example, where it came from, industry tags, a strength that practice raises and time lowers, and its history. Vocabulary is the word entries; definitions are the acronym entries; corrections stay corrections. The three lists migrate on the Mac first, with nothing lost; Settings › Dictionary becomes Settings › Library with a kind filter. The polisher, explain and the correction table read the same store through the same interface, and the corpus proves the behaviour is unchanged.
4. **A platform-neutral package, TimbreCore, is created with the Library.** The Library, pure parsing, practice scoring and the sync interface live there; no AppKit. TimbreKit imports it and keeps the macOS pipeline; the iPhone app imports only TimbreCore. The rule for what goes where is an ADR written with the split.
5. **Practice uses the voice, and every drill ships with a guardrail and a corpus.** Spell it (say the word, spell it aloud; the recogniser checks the letters), Say it (use it in a sentence; the on-device model judges the meaning), Explain it (answer the card by voice), the word of the day (weakest entries first, then a bundled list for the profile's industry, as a local notification), and the private kind of gamification — strength, streaks, a weekly review, no leaderboard. Each drill's checks go on the Evals page next to the polisher's. Spell it ships first, because it needs no model judgment.

## Consequences

- Phases 1–4 of the product map are now the plan: the Library on the Mac with the `TimbreCore` split; iCloud sync proved on two Macs with `nettop` still empty; the iPhone companion; Spell it with its corpus. Each phase is its own pull request and its own measurement.
- Nothing here changes a claim: the headline keeps one asterisk and `/network` keeps one entry.
- A Library entry is the user's. The Mac app transmits none of it; iCloud carries it under the user's own account.
