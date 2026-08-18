# 0003 — Spoken commands: structure only, never punctuation

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Dictation tools let you speak formatting aloud: "new paragraph", "period",
"comma", "bullet point". Spoke inherited the full list from its planning
notes, and the on-device model was asked to obey it in prompt rule 4.

It did not. Measured with `spoke-eval` (ADR-0004) the case failed **5 of 5
runs**, returning "Send it to the team. Period. New paragraph. Let me know if
anything breaks" — the commands transcribed as words, then capitalised into
sentences of their own. A worked example in the prompt appeared to fix it on a
single run and scored 0 of 5 repeated.

The deeper problem is that punctuation commands are **ambiguous by nature**.
"Period" is an ordinary English word: *the Victorian period*, *a grace period*,
*period drama*. No amount of prompting resolves that reliably, and a blind
find-and-replace would corrupt ordinary speech.

## Decision

Spoke supports **structural** spoken commands only:

| Spoken | Becomes |
|---|---|
| "new paragraph" | blank line |
| "new line" | line break |
| "bullet point" | new line, `• ` |

**Punctuation commands are not supported at all** — not by the model, not by
substitution. "Period", "comma", "question mark", "open quote" and "close
quote" are treated as ordinary words and pass through untouched.

The justification is that they are *redundant here*. Apple's built-in
dictation needs them because it has no cleanup layer. Spoke has one: the
polisher punctuates correctly on its own, so the user never needs to say
"period" to get a full stop. Removing them costs nothing a user wants and
removes a whole class of ambiguity.

Structural commands are resolved deterministically by `SpokenCommands`, before
the transcript reaches the model, following the principle set in
[ADR-0005](../adr/0005-deterministic-sentence-termination.md): a mechanical
transformation with a right answer should not be delegated to a 3B model.
Running before the model also means it punctuates around *real* line breaks
rather than around the words that named them.

## Consequences

- The corpus case went from 0 of 5 to passing, deterministically.
- Prompt rule 4 no longer describes commands. It now asks the model to
  *preserve* existing line breaks, which is necessary because the breaks are
  already in the text by the time it runs.
- **Users arriving from other dictation tools will say "period" out of habit
  and get the word.** This is the real cost. Accepted for now: the polisher
  makes the habit unnecessary, and the failure is visible and self-correcting
  rather than silent. Revisit if it turns up in real use.
- Structural commands retain a smaller version of the same ambiguity — "add a
  new line to the file" becomes a line break. Rarer than "period", and
  accepted on the same terms. Per-app profiles (roadmap 3) could disable
  substitution where it is known to be wrong, such as in a code editor.

## Alternatives considered

- **Keep prompting for the full list:** rejected on evidence — 5 of 5 failures
  across two prompt formulations.
- **Deterministic substitution for punctuation words too:** rejected — it
  corrupts ordinary speech, and corrupting real words is far worse than
  omitting a convenience.
- **Context-sensitive heuristics for "period"** (only at a clause boundary,
  only when followed by a capitalised word): rejected as unpredictable. A
  dictation feature that works most of the time is worse than one that is
  absent, because the user cannot build a reliable habit on it.
