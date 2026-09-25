# 0018 — Words appear as you speak; the cleanup replaces them on release

- **Status:** Accepted
- **Date:** 2026-09-25
- **Builds on:** [GDR-0001](0001-local-only-free-no-account.md) (everything still on-device), [ADR-0003](../adr/0003-insertion-via-pasteboard-paste.md) (the paste stays the paste), [ADR-0005](../adr/0005-deterministic-sentence-termination.md) and [ADR-0011](../adr/0011-polisher-decodes-greedily-capitalizes-deterministically.md) (the cleanup is unchanged)

## Context

Timbre's first dictation flow kept every word in the pill until the key was released, then polished and pasted. Measured on real dictations, the wait after release is about a second — 130 ms to finalize the transcript, 860 ms for the on-device model — and during speech nothing reaches the document at all. Hugo named it the most important thing about the product: Apple's dictation and the Claude app type as you talk, and next to them the pill "feels like it's slower", because the words sit in a bubble before they appear where they are wanted.

The speech model reports two kinds of text: *finalized* words it will never revise, and a *volatile* guess for audio still in flight. Measured with `timbre-eval --stream`, finalized text arrives in sentence-sized chunks while the user is still speaking, punctuated and capitalised, roughly a sentence behind the voice. That is enough to type from.

## Decision

1. **Confirmed words are typed into the app as they arrive.** Typed as keystrokes, not pasted, so the user's pasteboard is untouched while they talk. The pill shows only the words still in flight.
2. **On release, the remaining confirmed words are typed at once, then the cleanup runs on the whole utterance and replaces the typed run in one move**: the run is selected through the Accessibility API and the polished text is pasted over it. The cleanup itself — corrections, the model, the capital, the full stop — is unchanged.
3. **Never delete by count. Never guess.** The run is replaced only when the same field still has focus and the text between where the caret was and where it is now is recognisably what was typed — autocorrect and auto-capitals allowed, anything else not. Otherwise the words stay exactly as heard, and the pill says so.
4. **Only where the field can be read back.** At the start of a hold Timbre asks the focused element whether its selection is settable and its text readable. A field that says no — a terminal, a secure field, an element that hides its text — gets the pill-then-paste flow, unchanged from before.
5. **On by default, off in one toggle.** "Type as I speak" in Settings › General. Off is for shared screens, where the raw words should not be seen.
6. **Measured.** Two timings join the capture log: press → first typed word, release → replacement done. The corpus and the harness are unaffected, because the cleanup is unaffected.

## Consequences

- Dictation reads as typing rather than delivery: words land a sentence behind the voice, and release ends with a short fix-up rather than a wait.
- The raw words are briefly visible in the document, filler included, as with Apple's own dictation. The toggle exists for the moments that matters.
- A field that autocorrects the raw words as they land is fine; a field that transforms them beyond recognition (a rich editor that reflows into blocks, a form that reformats numbers) leaves the raw text in place. Each such app is a report, not a guess.
- ⌘Z after a dictation undoes the replacement first, back to the words as heard; a second ⌘Z removes those.
- Command mode and to-do capture do not type live; they never touch the field until a decision is made.
- The remaining latency after release is the model. Streaming its output into the replacement is the next measured step, kept separate because the capital and full-stop rules run on finished text.
