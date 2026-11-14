# 0033 — Learn: select it, say the word, and it comes back

- **Status:** Accepted
- **Date:** 2026-11-14
- **Amends:** [GDR-0012](0012-command-mode.md) and
  [GDR-0015](0015-command-mode-plain-verb-literals-fallback.md): command
  mode has a fifth word. The roadmap's rule — a fifth verb needs a guardrail
  that can score it — is met differently: learn writes no text, so there is
  nothing for a model to get wrong.
- **Builds on:** [GDR-0023](0023-the-library.md) (the Library),
  [GDR-0027](0027-word-of-the-day-the-bar.md) (the word of the day),
  [GDR-0014](0014-commands-act-on-the-word.md) (commands act on the word).

## Context

Timbre's purpose is learning and excelling at work. The moment a word is
worth learning is the moment it is met: in a message, a document, a pull
request. Until now, getting it into the Library meant opening Settings and
typing it. Explain already answers "what is this?" on a selection; nothing
kept the word afterwards.

## Decision

1. **Hold right ⌘ on a selection and say "learn".** The word or short
   phrase is saved to the Library, and its explanation is shown, as explain
   would show it. The user asked because they did not know it.
2. **Saving is deterministic and comes first.** `LearnTarget` decides: one
   word is a `word`, two to six words are a `phrase`, more is refused
   ("select one word or a short phrase"), the punctuation at the edges of a
   selection is dropped. No model is involved in what is saved, and no
   model-written meaning is stored: the model invents expansions it does
   not know (GDR-0012), and a stored guess would then answer explain first
   as if the user had taught it. The meaning is the user's to add.
3. **It comes back the way every entry does.** The entry gets a `taught`
   event, so it is in the daily pick, the word-of-the-day notification and
   practice, with strength from its events (ADR-0014). Learn adds no
   second reminder system.
4. **A term already in the Library is left alone.** Its meaning and history
   stay; the card says "already in your Library" and still explains.
5. **Learn never changes the user's text.** Like explain, it shows a card
   and pastes nothing. If the explanation fails, the pill still says the
   word was saved.
6. **The word is "learn"** (also "learning", "learned", "memorize",
   "memorise"). Not "remember" or "save": with nothing selected, a hold is
   a to-do (GDR-0016), and those words open too many of them. Learn waits
   for the whole word; only explain may fire on a prefix (GDR-0014).
7. **Provenance says how.** A new `how`, `learned`, with the app the word
   was met in. Never the sentence it was met in (GDR-0004).

## Consequences

- An acronym learned this way is a `word` until the user gives it a
  meaning; then explain answers from it first.
- The pill's hint has five words. Measured 2026-11-14 with
  `timbre-eval --live-commands`: "learn" in two synthetic voices and "learn
  this" were each recognised whole in the first live result, at about
  970 ms, and the session after the abandon still transcribed. A real
  voice is still the user's test.
- With nothing selected, "learn Spanish this week" is heard as the command
  and asks for a selection, as "fix the login bug" already does for fix.
  The to-do is not filed. This is the existing trade of GDR-0014, now one
  word wider.
- iPhone: explain and learn on a selection are Mac gestures; the companion
  shows the learned entries through the same Library.

## Alternatives considered

- **Store the model's explanation as the meaning.** Rejected, decision 2.
- **A separate "to learn" list with its own reminders.** Rejected: the
  Library, the daily pick and practice are that list.
- **Learn a whole sentence.** Rejected: there is no drill that can score a
  sentence, and the Library is terms.
