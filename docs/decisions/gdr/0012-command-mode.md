# 0012 — Command mode: hold right ⌘ on a selection to fix, explain or shorten it

- **Status:** Accepted
- **Date:** 2026-09-17
- **Builds on:** [GDR-0008](0008-voice-in-and-out.md) (voice in and out) and
  [GDR-0011](0011-taught-corrections-before-the-model.md) (taught corrections).

## Context

Timbre puts words in (hold right ⌥) and reads words out (tap left ⌥). The
third thing people do with text is change what is already there: a typo in
the sentence they just pasted, an acronym in a document they were sent, a
paragraph that says in sixty words what twenty would. Each of those is
currently a trip to another tool.

The on-device model that cleans up dictation can do all three. What was
missing was a gesture, and the rules for pointing a model at text the user
already wrote rather than text they are in the middle of saying.

Right ⌘ is the natural key — same hand and same hold-to-talk grammar as
dictation — but unlike right ⌥ it is a working shortcut key. People type ⌘P
with it and ⌘-click with it. A naive "right ⌘ went down" would open the
microphone on every one of those.

How the transcriber hears the commands was measured before the parser was
written (`say`, two voices, fourteen utterances): thirteen came back exact.
One voice's bare "shorten" came back as **"Jordan."** The phrase forms —
"shorten this", "make it shorter", "shorter" — were solid in both.

## Decision

Timbre has a **command mode**: select text, hold right ⌘, say one of three
words, release.

| Say | Timbre |
|---|---|
| **fix** — or nothing at all | corrects spelling, grammar and punctuation, changes nothing else, and pastes it over the selection |
| **explain** (also "acronym", "define", "what does this mean") | shows what the selection means in a card near the text; never pastes |
| **shorten** (also "shorter", "make it shorter", "trim") | says the same thing in fewer words and pastes it over the selection |

The rules:

- **It arms, it does not trigger.** Nothing happens until right ⌘ has been
  held alone for 350 ms. Any key, click or other modifier during the hold
  means it was a shortcut, and Timbre puts everything back silently. The pill
  appearing is the cue that releasing will now do something.
- **Silence means fix.** Releasing without a word is the default, and it is
  the safest of the three: a fix that finds nothing says "Looks right
  already" and touches nothing.
- **Never guess.** Two of the three commands rewrite the user's text. A word
  that is not a command does nothing, and the pill says what was heard —
  "Heard “Jordan” — say fix, explain or shorten." The user's taught
  corrections run over the command transcript too, so a stable mis-hearing of
  a command is teachable like any other.
- **Never destroy.** The polisher's contract is *always paste something*;
  this is the inverse. Model unavailable, an answer the guardrail rejects, a
  thrown error: the selection is left exactly as it was and the pill says so.
  A fix may only move a few characters; a shortening must be shorter and still
  be the text. The whitespace around a sloppy selection goes back on as it
  came off. A replacement is an ordinary paste, so ⌘Z undoes it.
- **Fix starts with what was taught.** The correction table runs first,
  deterministically (GDR-0011); the model only sees what is left.
- **Your dictionary answers first.** The user can define terms — "ADR" means
  "Architecture Decision Record" — and a selection that *is* a defined term
  is answered from that definition, word for word, with no model involved. A
  sentence that contains defined terms is explained by the model with those
  definitions handed to it as fact. This exists because of a measurement:
  asked about "ADR" in a sentence about architecture choices, the model said
  "Architecture Design Review" three runs in five, and not once "I am not
  sure", whatever its instructions said. It cannot know a user's jargon and
  does not know that it doesn't.
- **The card says where the answer came from:** "From your dictionary", or
  "On-device model · may be wrong". A taught definition and a model's guess
  deserve different amounts of trust, and only the user can tell which they
  are looking at if Timbre says so. On common terms the model is good —
  "API" and "RMS" explained correctly five runs in five.
- **No microphone is not a failure.** A silent hold means fix, and fixing
  needs no audio.
- **Keys are watched only during the hold.** Detecting "this was a shortcut"
  needs to know a key or the mouse was pressed. Those monitors exist only
  while right ⌘ is down, and their handler does not look at the event: it
  records that something happened, never what.

## Consequences

- Three verbs, not an open prompt. "Make this friendlier" is not supported,
  and that is deliberate: every verb here has a guardrail that can tell a
  good answer from a bad one. An open instruction does not.
- The commands are measured like the polisher is: `timbre-eval --commands
  Fixtures/commands.json --repeat 5`, properties not expected strings.
- In apps that hide their selection from Accessibility (Electron, terminals),
  the selection is read with a synthetic ⌘C after the key comes up. Editors
  that copy the whole line when nothing is selected will hand Timbre that
  line. It is one ⌘Z to undo, and it is the known rough edge.
- Definitions join vocabulary and corrections in the personal dictionary, so
  they travel with it if iCloud sync is turned on (GDR-0010, which already
  named acronym expansions as dictionary content).
- **Same selection, same command, same result.** Commands decode greedily,
  so nothing about the outcome is luck. How that was arrived at — and the
  schema leak and input-copying it uncovered — is
  [ADR-0009](../adr/0009-command-mode-decodes-greedily.md).
- Two smaller things also needed measuring before they were right: the model
  left "the the" alone three runs in five, so doubled function words are
  collapsed deterministically; and asked for two sentences it wrote eight, so
  explanations are cut to their opening sentences — safe only because they
  are never pasted.

## Alternatives considered

- **Fn / Globe:** rejected; macOS binds it to dictation and the emoji picker
  by default, and rebinding it is the user's setting to lose.
- **Trigger on key down, like dictation:** rejected; the microphone indicator
  would flash on every ⌘P.
- **Round an unknown word to the nearest command:** rejected; the nearest
  command to "Jordan" is a rewrite of someone's paragraph.
- **An open spoken instruction:** rejected for now; no guardrail can score it.
- **Paste the explanation:** rejected; it would replace the text it explains.
