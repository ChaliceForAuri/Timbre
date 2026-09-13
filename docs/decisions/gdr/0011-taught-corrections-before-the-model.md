# 0011 — Taught corrections: what Timbre heard becomes what you meant, before the model

- **Status:** Accepted
- **Date:** 2026-09-13
- **Builds on:** [ADR-0008](../adr/0008-taught-vocabulary-and-the-transcriber.md),
  which established that the transcriber cannot be taught. Part of the personal
  dictionary named in [GDR-0010](0010-optional-icloud-sync-of-personal-dictionary.md).

## Context

People say the same names every day — their product, their colleagues, their
tools — and the transcriber gets some of them wrong the same way every time.
"TimbreKit" comes out "timber kit". That stability is the lever: a
mis-hearing that is always the same is a lookup, not a language problem.

ADR-0008 measured the two places a fix was supposed to live. The speech model
ignores taught words outright. The polisher, handed "TimbreKit" in its prompt,
fixes "timbre kit" five runs out of five and "timber kit" never — a single
letter of phonetic distance is beyond what prompting a 3B model buys. Both
were measured, not assumed, with `timbre-eval` against fixture 11.

Timbre already has a precedent for this shape of problem. GDR-0003 moved
spoken structural commands out of the prompt into a deterministic pass
because a mechanical transformation with a right answer should not be
delegated to the model (ADR-0005). Corrections are the same shape.

## Decision

Timbre keeps a **correction table** in the personal dictionary: pairs of
*heard* → *meant*, taught by the user. "timber kit" → "TimbreKit".

- **Applied first.** Before spoken commands and before the model, so
  everything downstream sees the right words. `CorrectionTable` does it.
- **Whole phrase, case ignored, any spacing between the words, replaced
  verbatim.** "Timber Kit," becomes "TimbreKit,". A taught "kit" never
  touches "kitchen". Longest phrase wins where two overlap.
- **Never fuzzy.** A correction fires on exactly its phrase or not at all. No
  phonetic matching, no edit distance, no model in the loop. The same
  reasoning that kept punctuation commands out (GDR-0003): a guess that is
  usually right corrupts ordinary speech the rest of the time.
- **Absolute.** Once taught, the heard phrase can no longer be dictated
  literally. Teach "evils" → "evals" only if you never mean evils. Settings
  shows the whole table, so nothing rewrites text in secret.
- **The corrected spelling joins the vocabulary** automatically, so the
  polisher keeps it rather than "fixing" it back.
- **Taught in Settings**, for now: a heard field, a meant field, a list.
  Offering a correction from the user's own edits after a paste is the next
  step and gets its own record when it is built.
- **Syncs with the dictionary** under GDR-0010 when that ships, and nothing
  else does.

## Consequences

- Fixture 11 goes from unfixable to a real pass/fail case: with its five
  corrections taught, every term must survive the polisher, and does.
- The "spell kid" class of error has a home. It is fixed by the user once,
  not fought by the model every time.
- The cost is honest: a taught phrase is gone as ordinary text. The table is
  visible and each row is one click to forget.
- Acronyms are a candidate for the same table later — "A D R" → "ADR" is
  exactly a heard → meant pair — but that is a separate decision.

## Alternatives considered

- **Teach the transcriber:** rejected; ADR-0008 measured it ineffective.
- **Prompt the polisher harder:** rejected; 0 of 5 on a one-letter miss.
- **Fuzzy or phonetic matching:** rejected; it would corrupt ordinary
  speech, the same failure GDR-0003 refused for "period".
- **Per-correction hints to the model:** rejected; stochastic where the
  deterministic path is already right, and slower.
