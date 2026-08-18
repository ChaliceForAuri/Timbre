# 0006 — A speech session is single-use; rebuild it per dictation

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Spoke's first dictation worked. Every dictation after it showed the overlay,
metered the microphone, and produced nothing — no text, no error, and the
overlay simply vanished on release.

`Transcriber` held one `SpeechAnalyzer` and one `SpeechTranscriber`, both
created in `prepare()` at launch and reused for every dictation. Ending a
dictation called:

```swift
try await analyzer.finalizeAndFinishThroughEndOfInput()
```

The `AndFinish` is load-bearing. That call ends the analyzer permanently, and
the module's `results` sequence terminates with it. The API makes the
distinction explicit by offering both:

```
func finalize(through:)                      // finalize, keep going
func finalizeAndFinishThroughEndOfInput()    // finalize and finish
```

A finished analyzer still accepts `start(inputSequence:)` without complaint. It
just never produces a result, and the already-terminated `results` sequence
means the consuming loop exits immediately. Nothing throws. The failure is
totally silent — which is why it read as "the microphone isn't working" rather
than "the analyzer is dead".

## Decision

Treat a `SpeechAnalyzer` and its `SpeechTranscriber` module as **one
dictation's worth of machinery**. Both are rebuilt for every dictation.

`prepare()` keeps only the genuinely one-time work: resolving the locale,
installing model assets (which may download), and querying the best audio
format. It also builds the first session.

To keep the rebuild off the hot path, `finishDictation()` builds the *next*
session immediately after finishing the current one. A key press normally
finds a session already waiting.

## Consequences

- Dictation works repeatedly, which is the entire product.
- Two objects are allocated per dictation. Assets are already installed by
  then, so this is object construction rather than model loading, and it
  happens between dictations rather than during one.
- `prepare()` is no longer the only place sessions are created, so
  `Transcriber` now carries the resolved locale as state.
- Anyone reaching for `finalize(through:)` to keep one analyzer alive across
  utterances should know that path was not taken: the input sequence is
  per-dictation too (the audio engine stops between them), so a long-lived
  analyzer would need a long-lived input stream and a different `AudioCapture`
  design. Worth revisiting only if session construction ever shows up in a
  latency measurement.

## Verification

`spoke-eval --audio-dir` transcribes every fixture through a **single**
`Transcriber`, which is the reuse the app depends on and the thing a
single-file test cannot exercise. It reports 10/10; before this change it
would have reported 1/10.

That harness matters more than the fix. A unit test with one file would have
passed against the broken code.
