# 0015 — Command mode: a "plain" verb, guarded literals, and a spelling fallback

- **Status:** Accepted
- **Date:** 2026-09-25
- **Extends:** [GDR-0012](0012-command-mode.md), whose rule was "more verbs
  only if each comes with a guardrail that can score it", and whose known
  rough edges this record closes.

## Context

Tidy's release notes read like a list of things a model does to text when
nobody is watching: `@here` becoming "Here", `<@U01AB2CD3EF>` losing its
brackets, `14/08/2026` becoming "August 14, 2026", `30s` becoming
"30seconds", a leading "e.g." deleted, a single selected word capitalised,
and a selection that *contained* an instruction being obeyed. Every one of
those is a way to quietly damage someone's text, and Timbre's command mode
had no defence against any of them. Tidy also ships a second verb, "de-slop",
and a spelling-only fallback for Macs without Apple Intelligence.

All of it was measured on the command corpus before and after.

## Decision

**A literal guard.** Before fix, shorten and plain run, every Slack mention
and channel, URL, email, code span, path, date, time, number with a unit,
version and abbreviation (e.g., i.e., etc.) is replaced with a placeholder,
and put back afterwards. Fix must return every placeholder — a hole is a
refusal, and the text is left alone; shorten and plain may drop one, since
dropping is their job, but may not damage one. Explain never masks; it has to
read the literal to explain it. The placeholder is `LIT1`, `LIT2` …, because
measured across all three verbs the model strips brackets and symbols
(`⟦1⟧`, `[[1]]`, `{{1}}`, `<1>`, `§1`) in at least one of them and keeps a
word-shaped token in all of them.

**Fragments keep their case.** A fix on a selection that is short, starts
lowercase and ends without a full stop keeps its first letter lowercase:
"teh" becomes "the", not "The". A correction to a cased word — "iphone" →
"iPhone" — stands.

**The selection is material, never a message.** Fix's instructions say so,
as shorten's already did; the corpus carries an instruction-shaped selection
for both. Measured, the model was never obeying such text — it was leaving
it alone, which is the safe failure — but the rule is now written down and
tested rather than assumed.

**A fourth verb: plain.** Say "plain" (or "simple", "simplify", "human",
"deslop") and machine-sounding or corporate text comes back in plain, direct
English that says the same thing, in the author's voice — Tidy's de-slop,
ours. Its guardrail: the result stays between a tenth and 1.15 times the
length of the original, and a result identical to the input is reported as
"Already plain", not pasted. The floor is a tenth because pure filler can
honestly reduce to one sentence: a 325-character memo whose whole content is
"onboarding is a problem" came back as those 39 characters, and that is the
plain truth of it. Prompt shape was chosen on the corpus: of four variants,
one passed every case; two with longer buzzword lists got worse on the case
that matters most.

**A spelling fallback.** With Apple Intelligence unavailable, fix still
runs: taught corrections, doubled words, then macOS's own spell checker, word
by word — its confident correction, or its first guess when that guess is
within two edits. Literals are guarded first (the checker "fixed" the eng in
#eng-releases before that), taught words are never touched, and neither is
a capitalised word inside a sentence, which is most names. Measured with
`timbre-eval --commands --without-model`: 8 of 9 fix cases, the miss being
apostrophes, which spelling alone cannot do and which the fallback does not
pretend to.

## Consequences

- The corpus grows from 12 to 24 cases and passes 24/24 at two repeats;
  every case above is in it, so a regression in any of these is a red line
  in the harness, not a release note.
- The pill's hint reads "fix · explain · shorten · plain". Four verbs is
  the ceiling until a fifth brings a guardrail of its own.
- A word that happens to look like a placeholder (`LIT1`) in the user's own
  text would be mistaken for one and refused as invented. Accepted: it does
  not occur in prose.
- The literal patterns are English- and Latin-script-shaped, like the rest
  of Timbre (GDR-0002).

## Alternatives considered

- **Trust the prompt to preserve literals:** rejected; measured, it did not.
- **A blanket "no changes to anything with a digit":** rejected; "3 in the
  morning" is prose, and the patterns are narrower than that on purpose.
- **Spell-check before the model on every fix:** rejected; the checker's
  guess for a lowercase surname two edits from a real word ("pretorius" →
  "Pretorian") is exactly the damage the guard exists to prevent. It runs
  only when the model cannot.
- **Add the buzzword list to the prompt:** measured, worse; the model
  started reproducing the words it was told to remove.
