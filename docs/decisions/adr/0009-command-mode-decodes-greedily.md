# 0009 — Command mode decodes greedily; only fix uses guided generation

- **Status:** Accepted
- **Date:** 2026-09-17

## Context

Command mode (GDR-0012) points the on-device model at text the user already
wrote. Its first implementation copied the polisher: default sampling, and
`@Generable` guided generation for every command. Measured with `timbre-eval
--commands` at five repeats, that produced three separate problems.

**Variance.** With the fix prompt unchanged between two runs, the case
`fix-keeps-meaning` scored 5 of 5 and then 1 of 5. Five repeats were not
taming the sampling, and for a proofreader the variance is itself the
defect: the same selection and the same command should give the same result.

**Schema leak.** Asked to explain a bare "API", the model answered with a
description of its own output format — "the schema specifies that the 'text'
property must be a string". `respond(to:generating:)` includes the schema in
the prompt by default, and with no other context the model explained the
only context it had.

**Copying.** Under greedy decoding, shorten returned its input verbatim four
times out of four. The most likely continuation of "keep every fact, keep
the voice" is the original. Fourteen prompt variants were then measured,
deterministically, across four texts:

| What changed | Cases shortened |
|---|---|
| Stronger instructions, "about half as many words" | 0 of 4 |
| An explicit word budget, stated before the text | 2 of 4 |
| The same budget stated *after* the text | 2 of 4 |
| … and plain-text generation instead of guided | 3 of 4 |
| Seeded sampling at 0.4 or 0.7 instead of greedy | 1–3 of 4, some lower-cased or telegraphic |
| A sentence budget | 3 of 4 |
| Fenced text, budget after it, "keep who it is addressed to, every fact, and every request" | **4 of 4** |

One text — an email opening "Hi Sarah," — came back untouched under every
variant but the last. Unfenced, it reads as a message to pass through rather
than material to edit.

## Decision

We will decode every command with `GenerationOptions(sampling: .greedy)`.

We will use guided generation for **fix** only, with
`includeSchemaInPrompt: false`; **shorten** and **explain** generate plain
text, passed through `OutputCleaner` in case the fence or a pair of quotes is
mirrored back.

The shorten prompt fences the selection, states the instruction after it
with a word budget of half, and names what must survive. A shortening that
comes back no shorter is reported as "That's already tight", not as a failure.

## Consequences

- The command corpus is a measurement rather than a dice roll: 12 of 12, and
  identical on every run. `--repeat` now checks determinism, not luck.
- Same input, same output is also a product property worth having. A user
  who undoes a shortening and asks again gets the same answer — which is
  honest, if occasionally unhelpful.
- A greedy answer that is wrong is wrong every time. The guardrails and the
  "never destroy" rule (GDR-0012) are what stand behind that, not a retry.
- The polisher still samples, and still includes its schema in the prompt.
  Both are now suspects for its known flake (issue #27) and should be
  measured the same way before being changed.
- The prompt shapes here are tuned to one model version. A new OS can move
  them; the corpus is how we will know.

## Alternatives considered

- **More repeats with default sampling:** rejected; it measures the variance
  more precisely without removing it from the product.
- **Seeded sampling:** rejected; reproducible, but measured worse than greedy
  with the right prompt, and produced lower-cased and telegraphic outputs.
- **Guided generation everywhere:** rejected on the schema leak and the copying.
- **Retry with sampling when greedy copies:** rejected once the prompt shape
  fixed the copying; it would have bought back the variance.
