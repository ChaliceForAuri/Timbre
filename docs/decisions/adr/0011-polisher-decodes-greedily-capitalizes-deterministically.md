# 0011 — The polisher decodes greedily; sentence capitals are deterministic

- **Status:** Accepted
- **Date:** 2026-09-25
- **Extends:** [ADR-0005](0005-deterministic-sentence-termination.md) (the
  final full stop) and [ADR-0009](0009-command-mode-decodes-greedily.md)
  (greedy decoding for commands), which named the polisher's sampling as a
  suspect for issue #27 and asked for it to be measured first.

## Context

The polisher's one flaky corpus case (#27: "like" surviving cleanup one run
in five) was suspected to be sampling variance, the same variance ADR-0009
removed from command mode. Measured on the eleven-case corpus at five
repeats:

| Decoding | Cases passing every run | Distinct outputs per case |
|---|---|---|
| Default sampling, schema in prompt | 10/11 | up to 3 |
| Greedy, schema out of prompt | 11/11 | 1 |

Greedy also exposed something sampling had been hiding: for short casual
inputs the model's most likely output starts lowercase — "the deploy went
out this morning.", "yep that works.", "yeah that sounds good to me lets just
do it." — every time. Under sampling the same cases came back capitalized
sometimes and not others. Instruction 3 asks the model for capitalization;
like the final full stop (ADR-0005), it is a mechanical rule the model
applies unreliably, and a deterministic step applies perfectly.

## Decision

`TextPolisher` decodes with `GenerationOptions(sampling: .greedy)` and keeps
the schema out of the prompt. The same words get the same cleanup, every
time.

`SentenceCapitalizer` runs after the model on every path, before the
terminator: the first letter of the text and of each sentence after `.` `!`
`?` or a line break is uppercased. Words that carry their own casing (iPhone,
macOS, eBay) are left alone; an abbreviation's dot (e.g., i.e., a.m.) is not
a sentence end; a quote or bracket at a sentence start is looked through.
The corpus checks every output for an initial capital.

## Consequences

- 11/11 at five repeats, one output per case. #27 is closed by measurement.
- A greedy answer that is wrong is wrong every time; the corpus is what
  catches it, and `--repeat` now tests determinism rather than luck.
- The prompt still says "capitalization" in instruction 3. It stays: the
  model handles mid-sentence proper nouns, which the rule does not touch.
- Two deterministic passes now bracket the model — capitalizer and
  terminator — and both run on the fallback path, so a raw transcript pasted
  because the model was unavailable still reads as a sentence.

## Alternatives considered

- **Keep sampling and add the capitalizer:** rejected; it fixes the visible
  symptom and keeps the variance that produced #27.
- **Ask harder for capitals in the prompt:** rejected on ADR-0005's
  evidence; asking twice for the full stop failed five of five.
- **Uppercase the first letter unconditionally:** rejected; "IPhone".
