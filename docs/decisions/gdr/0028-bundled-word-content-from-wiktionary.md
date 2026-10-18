# 0028 — Bundled word content comes from a Wiktionary extract, under CC BY-SA; the model writes only examples

- **Status:** Accepted (implementation pending)
- **Date:** 2026-10-18
- **Builds on:** [GDR-0005](0005-licensing-preserves-optionality.md) (the
  app's code stays closed; a lawyer's eye before going public),
  [GDR-0001](0001-local-only-free-no-account.md) and
  [GDR-0006](0006-app-never-phones-home.md) (no network),
  [GDR-0012](0012-command-mode.md) (the model invents what it does not
  know), [GDR-0023](0023-the-library.md) (the bundled list for the
  profile's industry), [GDR-0027](0027-word-of-the-day-the-bar.md).

## Context

The word of the day needs a definition, a part of speech, a pronunciation
and an origin for thousands of words, on-device, with no network. Three
sources exist:

- **The on-device model.** Fast and personal, and measured to invent
  expansions for acronyms it does not know (GDR-0012). An origin it has never
  seen is a story, not a fact. A guardrail for it would need a source of
  truth, which brings the dataset back.
- **Apple's dictionary.** On the Mac, `DictionaryServices` returns a real
  New Oxford American definition on-device. On iOS it only shows one in a
  sheet; there is no text API, and the content cannot be redistributed. Fine
  as a supplement on the Mac, not a foundation.
- **Open data.** WordNet: permissive, excellent senses and synonyms, no
  etymology and no pronunciation. Wiktionary: the only open source with
  etymology and IPA at scale; text dual-licensed CC BY-SA 4.0 and GFDL;
  machine-readable through `wiktextract`, whose output kaikki.org publishes
  under the same two licences.

Hugo chose Wiktionary, for the origins.

## Decision

**Timbre bundles a curated extract of English Wiktionary for the bundled
lists and for the facts on a Library entry's card. The extract is a
derivative work under CC BY-SA 4.0 and is treated as one. The app's code
stays under GDR-0005's terms. The model writes example sentences and the
"why today" line, labelled as the model's, and never a fact.**

- **Attribution in the app.** Every card that shows extract content says
  *Source: Wiktionary*, linked; an *About the words* screen carries the
  licence, the attribution and the link to the extract. A user's own meaning
  is theirs; a model-written line is labelled *written by the model*.
- **Share-alike applies to the extract, and we honour it.** The curated
  extract Timbre ships — the JSON in the bundle — and the scripts that
  produce it are published under CC BY-SA 4.0, separate from the app's code.
  Data and code are separable: the extract is a file the app reads, not a
  part of the program. GDR-0005's review before going public covers this
  reading; the reasoning is recorded here so that review has something to
  check.
- **We rely on CC BY-SA, not the GFDL.** The dual licence lets a reuser
  choose; share-alike under CC BY-SA is the practical one for data.
- **The extraction runs on our side, never in the app.** A tool in `tools/`
  takes a kaikki dump and the word lists and emits the bundle: the chosen
  senses, part of speech, IPA, etymology, word parts, and nothing else. The
  app ships the result. Updating the content is a release, and the extract's
  licence file is in the bundle.
- **The lists, in order:** tier-two general English; software and product;
  healthcare, law, finance and design; phrases and idioms alongside words
  (GDR-0027). Each is curated — senses chosen, a review pass — before it is
  promised in copy.
- **Size is measured, not guessed.** A budget for the bundle is set in the
  engine's ADR from a real extract of the chosen lists.
- **Pronunciation is IPA from the extract, spoken by the system voice**
  (GDR-0008). The IPA is shown; the voice says the word.

## Consequences

- A `LICENSE` for the data joins the repository beside the app's; the public
  extract repository (or a public folder of this one, if the code goes
  public) carries the same.
- The Mac may supplement a card with Apple's definition where it has one,
  labelled as such; the phone and Watch show the extract alone.
- Where the extract lacks a field, the card leaves it out and says so. No
  field is ever filled by the model.
- Curation is real work and it is on the critical path for every list after
  general English.

## Alternatives considered

- **WordNet:** rejected for the foundation — no origins, no pronunciation;
  it may return as a source of synonyms for practice, with its own
  attribution.
- **The model alone:** rejected; invented origins presented as facts, exactly
  the failure GDR-0012 built a guardrail against.
- **Apple's dictionary alone:** rejected; Mac-only, not redistributable, no
  API on iOS.
- **A commercial dictionary API:** rejected; a network request, a cost, an
  account — GDR-0001 and GDR-0006 in one stroke.
