# 0027 — The word of the day: the bar is Vocabulary.com and the widget apps, and the word is yours first

- **Status:** Accepted (implementation pending)
- **Date:** 2026-10-18
- **Builds on:** [GDR-0023](0023-the-library.md) (decisions 3 and 5: the
  Library's strength and history; the word of the day, weakest entries
  first, then a bundled list), [GDR-0028](0028-bundled-word-content-from-wiktionary.md)
  (where the facts come from), [GDR-0026](0026-apple-watch-the-wrist-key.md)
  (the wrist), [GDR-0008](0008-voice-in-and-out.md) (voice out),
  [GDR-0004](0004-opt-in-local-dictation-capture.md) (what is never stored).

## Context

Hugo set the bar: the word of the day must beat the current flagship, and
there are two flagships.

**Vocabulary.com** (IXL) is the substance. Lexicographer-written
definitions; a trainer that rates every answer on a twenty-level scale and
picks the next question by comparing you with hundreds of millions of other
users' answers; ten question types, including real-world example sentences;
brush-up questions as time passes; mastery lists, achievements,
leaderboards. Its word of the day is a daily page and email: a plain gloss,
an illustrative sentence, the word's parts, its origin, an archive. It needs
an account and a server, and it has never seen a word from your life.

**The iPhone word-of-the-day apps** ("Vocabulary – Learn words daily" and
its kind) are the presence. A word on the Lock Screen and the Home Screen,
Oxford-sourced content, streaks, an assessment-based plan, a subscription.
They pick from a list, and the list does not know you.

GDR-0023 already gave the word of the day its shape: the Library's weakest
entries first, then a bundled list for the profile's industry, as a local
notification, and *saying it in a dictation that day marks it met*. What it
did not say is what "good" means. Timbre has what neither flagship has: the
words you actually dictated, had explained, misspelled and taught; your
voice, on-device; and a place on the Mac's menu bar, the iPhone's Lock
Screen and the Watch's face. It lacks what they have: a corpus of real
sentences, a population to compare you against, and a lexicographer. This
record is about competing where we win, honestly.

## Decision

**Timbre's word of the day is judged against both flagships, and it ships
only when four things are true.**

1. **The word is yours first.** The pick comes from the Library: the weakest
   entry that is due, by the spaced-repetition strength (GDR-0023,
   decision 3). Only when the Library has nothing due does a bundled list
   supply the word, chosen by the profile's industry (GDR-0028): general
   English first, then software and product, healthcare, law, finance and
   design, with phrases and idioms alongside words. Never random: the pick
   is a deterministic function of the Library's state and the date, which
   is what makes it testable.
2. **Practice is spoken.** The drill attached to the word is Spell it, Say
   it or Explain it (GDR-0023, decision 5), scored on-device. No multiple
   choice.
3. **It is ambient, and it marks itself.** A menu bar item and a notification
   on the Mac; a widget and a Lock Screen control on iPhone; a complication
   and a Smart Stack card on the Watch (GDR-0026). When the word appears in a
   dictation or a command that day, the Mac marks it *met* — from the
   polished text, after corrections, while it is still in memory. The
   Library stores that it was met and when, never the sentence (GDR-0004).
   Meeting a word in the wild counts as a review; it is better evidence than
   a drill.
4. **The entry is deep.** Definition, part of speech, pronunciation, origin
   and word parts where known — from the bundled extract, labelled as its
   source — plus an example sentence written by the on-device model for the
   user's industry, labelled as the model's, and one line saying *why this
   word today*: which event in the Library earned it. The model never writes
   a fact. Where the extract has no origin, the card says so rather than
   inventing one.

Around it, as GDR-0023 said: a streak of days met or practised, a weekly
review, strength bars — the private kind of game. No leaderboard, no
sharing, nothing that needs a server.

## Consequences

- The Library's strength and history exist before the word of the day does;
  the engine is `TimbreCore` (GDR-0023, decision 4) and the Mac is its first
  surface (product map §7).
- The bundled lists are data with their own licence and a curation job
  (GDR-0028). The profile chooses among them; a user with no profile gets
  general English.
- *Met* detection runs in the polisher's path on the Mac and in practice on
  the phone: a whole-word, case-insensitive match against today's word in
  text that is already in memory. It adds no storage and no capture.
- The harness gets a corpus: Library states and dates in, expected picks
  out, repeated for determinism (ADR-0004's discipline). "Better than
  Vocabulary.com" is argued from the four properties, not from a benchmark we
  cannot run against their system.
- The marketing says exactly what we do not have — ten question types, a
  corpus of real sentences — and what they do not: your words, your voice,
  nothing leaving your devices.

## Alternatives considered

- **A random word from a good list:** rejected; that is every app in the
  category.
- **Reproduce the adaptive multiple-choice trainer:** rejected; it needs
  their data and a server, and multiple choice is not a voice interface.
- **Definitions written by the model:** rejected; it invents origins and
  expansions (GDR-0012 measured this for acronyms). Facts come from the
  extract (GDR-0028).
- **Leaderboards and sharing:** rejected; a server, and a game played at the
  user's expense (GDR-0006).
