# 0005 — Terminal punctuation is deterministic, not the model's job

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Polished text routinely came back without a final full stop. The model
punctuated *between* sentences and left the last one open, so a user pasting
one sentence into Slack got it unterminated and had to type the full stop
themselves — every single time, which defeats the point of the app.

[ADR-0004](0004-evaluation-harness-seam.md)'s harness measured it rather than
guessing, and two rounds of prompt tuning failed to move it:

1. Rule 3 was made explicit: "Every sentence ends with a full stop, question
   mark, or exclamation mark, including the last sentence in the text."
2. The same constraint was added to the `@Guide` description, right at the
   generation site.

After both, cases 06 and 08 still failed **5 of 5 runs**. The model is ~3B
parameters; this is not a capability it reliably has.

## Decision

`SentenceTerminator` adds the final full stop deterministically, as the last
step of `TextPolisher.polish`. The prompt no longer asks for it — rule 3 keeps
responsibility for punctuation *within* the text, which the model does handle
well, and says explicitly that the final stop is added afterwards.

Two supporting choices:

- **The condition is an allowlist.** A full stop is appended only when the
  deciding character is a letter or a digit. Every other ending — an ellipsis,
  a clause mark, a dash, an emoji, a symbol — is left alone by default. A
  blocklist would have needed to anticipate emoji to avoid "sounds good 👍.";
  the allowlist never had to think about them.
- **The deciding character is found by looking past closing quotes and
  brackets**, so `(see the docs.)` is recognised as already terminated while
  `(see the docs)` is not.

`polish` was restructured to a single exit point so the guarantee holds on
*every* path, including the fallbacks where the model never ran or the
guardrail rejected its output.

## Consequences

- The pasted text always ends a sentence, whether or not Apple Intelligence is
  available. That is a stronger contract than the prompt could offer.
- Prompt attention is freed for work only the model can do. Context is scarce
  on a small model and an instruction it ignores is not free.
- **Fragments get a full stop they may not want.** Dictating "quarterly report
  draft" into a filename field yields a trailing stop. Accepted: Spoke's case
  is prose, and the polisher already capitalizes and punctuates such input, so
  this does not create the mismatch — it makes an existing one consistent.
  Revisit if per-app profiles (roadmap 3) arrive, where a field type is known.
- The corpus's `requiresPunctuation` check now tests this guarantee rather than
  the model. That is the intent, but it means the check can no longer detect
  the model regressing on punctuation.

## Alternatives considered

- **Keep tuning the prompt:** rejected on evidence — two attempts, 5 of 5
  failures remaining, and each attempt costs context the model needs elsewhere.
- **Replace a trailing comma with a full stop:** rejected. Almost certainly an
  improvement, but it guesses at intent, and this codebase's rule is that a
  guardrail never makes the text worse. Left alone and documented.
- **Terminate every line, not just the end:** rejected — bullet lists and
  deliberate line breaks would collect stray stops.
