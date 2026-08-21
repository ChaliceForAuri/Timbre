# 0008 — Timbre is a voice interface, not a dictation app

- **Status:** Accepted
- **Date:** 2026-08-21

## Context

Timbre shipped as dictation: hold a key, speak, get text. The natural
complement — select text, have the Mac read it back — was proposed with a
specific gesture: hold to read, and re-press to speed up.

Three things made it worth doing rather than merely possible:

- **The infrastructure already existed.** Accessibility permission, a
  global hotkey monitor that already distinguishes left from right Option by
  device flag bit, a non-activating overlay, and pasteboard save/restore.
  Reading a selection is `TextInserter` run backwards.
- **The privacy story extends unchanged.** macOS voices are on-device, so
  GDR-0001 survives verbatim: still zero network requests.
- **It is a better product.** "Voice in and voice out" justifies a paid
  licence in a way that dictation alone has to work harder for, and reading
  your own writing back is a genuine proofreading tool — the ear catches
  what the eye skips.

Against it: **macOS already has Speak Selection** (Accessibility › Spoken
Content, ⌥Esc). Shipping a worse version of a built-in feature is pointless.
The bar is being better, and the room to be better is real: the system's
version is a buried toggle with no speed control while it talks.

## Decision

Timbre does voice in *and* voice out. Read-aloud is bound to **left Option**
— right hand talks, left hand listens — and is **tap-driven, not
hold-driven**:

| Gesture | Action |
|---|---|
| Tap | Start reading the selection |
| Tap while reading | Climb one rung of the speed ladder (1× → 1.25× → 1.5× → 2×) |
| Hold (350 ms) | Stop |

The proposed hold-to-read was rejected on ergonomics. Dictation is naturally
bounded — eight seconds of speech — but a paragraph takes ninety, and
holding a key that long occupies the hand and defeats the purpose: listening
happens *while doing something else*. The speed-up insight was kept intact,
because it is the good half of the idea and nothing comparable exists in the
built-in feature.

Consequences that constrain implementation:

- **Starting a dictation stops any reading.** Two voices at once is never
  what anyone wants.
- **The ladder stops at the top rather than wrapping.** Wrapping would drop
  a listener from 2× to 1× on a stray tap.
- **Reading never speaks the clipboard.** When the pasteboard fallback is
  used and the copy doesn't change the pasteboard's change count, there was
  no selection — and speaking whatever the user last copied is an alarming
  thing for an app to do unprompted.

## Consequences

- `DictationController` now coordinates both modalities and is a misnomer.
  Renaming it is deferred rather than forgotten: it is public API, and the
  rename is mechanical churn that shouldn't ride along with the feature.
- Read-aloud needs no new permissions. Accessibility already covers reading
  the selection and posting the synthetic ⌘C.
- Speed changes restart the utterance from the current word, because
  `AVSpeechUtterance.rate` is fixed once speaking begins. The progress
  delegate makes this invisible; without tracking position it would sound
  like a restart, and the feature would be worthless.
- The product's name gets truer. "Timbre" covers both directions.

## Alternatives considered

- **Hold-to-read, as proposed:** rejected on ergonomics, above.
- **Both gestures (tap plays, hold previews):** rejected for now — two
  behaviours on one key is hard to discover, and the preview case has no
  demonstrated need.
- **Deferring until the polisher is tuned:** rejected because the polisher
  work is blocked on capture data accumulating, not on developer time. This
  filled a real gap rather than competing for one.
