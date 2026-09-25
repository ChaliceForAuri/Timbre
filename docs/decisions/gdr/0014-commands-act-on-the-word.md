# 0014 — Command mode acts on the word, not on the release

- **Status:** Accepted
- **Date:** 2026-09-24
- **Amends:** the gesture in [GDR-0012](0012-command-mode.md) — "say one of
  three words, release". Every other rule in GDR-0012 stands: arm after
  350 ms, never guess, never destroy.

## Context

The first real use of command mode, by Hugo: "really good, but not
intuitive. If it hears explain it should immediately action it, not wait for
me to release it." Saying a word and then having to let go of a key before
anything happens is two actions for one intent, and the second one has no
feedback: you have spoken, the pill shows your word, and nothing moves.

The speech model already produces live results while the key is held — the
pill displays them. What had not been measured was whether they arrive early
enough, and whole enough, to act on. `timbre-eval --live-commands` feeds each
spoken command at microphone pace, with the silence of a key still held after
it, and records when a command word first appears:

| Spoken | First live result | Whole word |
|---|---|---|
| "fix", "fix this" | ~1.0 s: "Fix" | first burst |
| "shorten this", "make it shorter" | ~1.0 s: "Short", "Make it shorter" | first burst |
| "explain" | ~1.1 s: "Ex", "Expl" | ~2.0 s |
| "acronym" | ~1.1 s: "Ac", "Acr" | ~3.0 s |
| "shorten" (one synthetic voice) | "Jordan" | never |

Times are from the start of speech; the words themselves last 0.5–0.9 s.
Fix and shorten arrive whole in the first burst. Explain — the command most
worth having instantly — arrives as a *partial* word first, and waiting for
the whole word costs a full second.

## Decision

A command runs **the moment a live result contains its word**, whether or
not the key is still down.

- **Explain may fire on a partial word:** the last word of a live result, at
  least three letters, when every command word it could be finishing means
  explain ("Expl", "Acr", "Defi", "Wha"). Explain never touches the user's
  text, so the worst misfire is a card nobody asked for. A prefix that could
  also finish a fix or shorten word ("Con", "Cor") waits.
- **Fix and shorten need the whole word.** They rewrite text; a partial is
  not enough to commit to that.
- **Silence still means fix, on release.** Silence mid-hold only means "not
  yet".
- **A command fires once.** A live result, the key coming up, and a late
  final result arriving during the release are three ways to run the same
  command twice; `CommandHold` lets only the first count.
- **Once fired, the hold is spent.** The speech session is dropped rather than
  finalized (0–2 ms, and the next session is checked to still work —
  ADR-0006), the shortcut watch stops, and releasing the key does nothing.
- **The explanation streams into the card** as the model writes it: the card
  opens with its first words about 0.3 s after the command is recognised and
  is complete by about 0.65 s.
- **Taught corrections apply to live results too**, so a voice that says
  "shorten" and is heard as "Jordan" can teach it once (GDR-0011).

## Consequences

- From the start of saying "explain" to the card opening with words: about
  1.3 s, down from ~2 s of recognition plus a release plus a finalized
  session plus a whole non-streamed answer.
- The pill's hint still reads "fix · explain · shorten", and saying nothing
  still fixes; the only change a user can see is that things happen sooner.
- A misheard partial can open an explanation card for a word that was never
  a command ("exp…ort"). Accepted for explain only, for the reason above.
- `timbre-eval --live-commands` is the instrument for anything that touches
  this path: a new engine, a new alias, a new SDK.

## Alternatives considered

- **Keep act-on-release:** rejected; it is the complaint.
- **Fire on any partial prefix, all commands:** rejected; "con…firm" would
  shorten someone's paragraph.
- **Wait for a final result instead of a live one:** rejected; finals arrive
  about a second later, which is the delay being removed.
- **Add "jordan" as an alias for shorten:** rejected; that is guessing at one
  synthetic voice's mishearing, and the correction table is the honest route.
