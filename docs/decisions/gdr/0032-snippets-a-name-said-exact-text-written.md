# 0032 — Snippets: a name said, exact text written

- **Status:** Accepted
- **Date:** 2026-11-13
- **Amends:** decision 3 of [GDR-0023](0023-the-library.md) — "one Library,
  five kinds" becomes six. The rule behind it stands: a kind that is
  *learned* needs a drill that can score it. A snippet is not learned.
- **Builds on:** [GDR-0011](0011-taught-corrections-before-the-model.md) (a lookup before the
  model), [GDR-0015](0015-command-mode-plain-verb-literals-fallback.md) (placeholders the model
  leaves alone), [GDR-0003](0003-structural-spoken-commands-only.md) (an utterance
  that is only a command gets no capital and no full stop).

## Context

The user wants to say their email address and have it written right, every
time; and the same for the commands and fragments a developer types daily.
Speaking the text itself does not work, and cannot be made to: measured on
2026-11-13, "hugo pretorius at gmail dot com" came back from the transcriber
as "Hugo Pretoria's at gmail.com" in a sentence and "Hugo Pretoria is at
gmail.com" alone. The transcriber cannot be taught (ADR-0008), and an
address has exactly one right spelling.

A taught correction almost does it — say a phrase, get other text — but a
correction's text then goes through the model, the capitalizer and the
terminator like any other words. "My email." alone would paste as
"Ada@example.com." with a capital and a full stop, both wrong.

## Decision

1. **A snippet is a short name the user says and the exact text it stands
   for.** The name is ordinary words the transcriber hears reliably ("my
   email", "status command"); the text is never spoken, so never mis-heard.
2. **A sixth kind, `snippet`, in the one Library.** The name is the entry's
   `heard` side and its identity; the text is its `term`. It is not
   learnable: no word of the day, no drill, no strength. It syncs, exports
   and is forgotten like any entry.
3. **Said alone, the snippet is the whole paste**: its text, verbatim, with
   no capital and no full stop added, and the model never runs. Case,
   spacing and the punctuation the transcriber adds around the name are
   ignored.
4. **Said inside a sentence, the text is out of reach until the end.** The
   name becomes a placeholder (`SNIP1`) before the spoken commands and the
   model; the capital and the full stop are decided on the placeholder; the
   text is put back last. A cleanup that drops a placeholder is discarded
   for the uncleaned sentence: the snippet is never lost and never altered.
5. **Deterministic, after corrections.** `SnippetTable` is a lookup in
   TimbreCore, longest name first, whole words only. Taught corrections run
   before it, so a name the transcriber keeps mis-hearing can be repaired
   the usual way.
6. **Not for secrets, and the product says so.** A snippet is stored as
   plain text in the Library file and syncs with it. Settings says "not for
   passwords" where snippets are added.

## Measured

`timbre-eval Fixtures/corpus.json --repeat 5`, 2026-11-13: 14 of 14 cases,
70 of 70 runs. The three new cases — a snippet alone, one mid-sentence with
fillers around it, one opening the sentence — pass 5 of 5, and the model
kept the placeholder in every run with no change to its instructions. The
eleven earlier cases are unchanged.

## Consequences

- Dictation only. Command mode and spoken to-dos do not expand snippets;
  either is a later record.
- A snippet's name is taken out of ordinary speech: with "my email" saved,
  "I read my email this morning" writes the address. Names should be
  phrases the user would not otherwise say; the Settings copy shows
  examples, and this is the first thing to watch in real use.
- Live typing shows the name as it is spoken and replaces it on release,
  like every other cleanup (GDR-0018).
- The data inventory's Library row names snippets: they are the entries
  most likely to hold personal data.

## Alternatives considered

- **Teach the address as a correction.** Rejected: capitalised and
  terminated when said alone, and open to the model inside a sentence.
- **Tag corrections as verbatim instead of adding a kind.** Rejected: a tag
  that changes pipeline behaviour is a kind in disguise, and hiding every
  correction from the model would stop it fixing the grammar around them.
- **Speak the text and repair it with the model.** Rejected by the
  measurement above, and by GDR-0011: a transformation with a right answer
  is not delegated to a 3B model.
