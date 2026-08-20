# Field notes

Things learned *building* Spoke, as opposed to things known before it started.
[Spoke University](spoke-university.html) covers the durable domain knowledge —
Swift, concurrency, audio, speech, on-device models. This file is the empirical
record: what actually happened when the code met the hardware.

Newest first. Append; don't rewrite history.

---

## 2026-08-19 — "Completely against the edge" was the whole answer

The overlay kept appearing in the bottom-left corner. Two theories were
engineered before the bug was found by reading the file top-to-bottom:
Electron coordinate systems (plausible, wrong) and the mouse fallback (a
real design flaw, also not the bug). The actual cause: a guard added during
the flicker fix skipped *placement* whenever SwiftUI hadn't produced a
layout size yet — and an unplaced AppKit window sits at its creation origin,
(0,0), the bottom-left corner.

The user's report contained the discriminating detail from the start:
"completely against the edge." Every positioning path clamps with a 12 pt
margin; only a window that was never positioned sits flush. Taking the
observation literally would have skipped both theories.

Related finds from the same hunt:

- **A window that is never explicitly placed appears at (0,0).** Corner-flush
  placement is the signature of missing placement, not wrong placement.
- **`NSHostingView.fittingSize` is zero before the first SwiftUI layout
  pass**, which is exactly when a panel must first be placed. Resolve a
  fallback size; never skip.
- **Never anchor UI to the mouse while the user is typing.** The pointer
  sits wherever it was abandoned. Caret if the app reveals it, deliberate
  HUD otherwise.
- **`log show` on this machine returns nothing for our subsystem — even for
  a trivial test script.** Two rounds of os.Logger instrumentation were
  unreadable flying blind. Verify the observation channel before trusting
  what it fails to show.

---

## 2026-08-18 — A SpeechAnalyzer is single-use, and says nothing about it

Symptom: the first dictation worked. Every one after it showed the overlay,
metered the microphone, and produced no text — no error anywhere.

`finalizeAndFinishThroughEndOfInput()` ends the analyzer **permanently**. The
`AndFinish` is not decoration; the API offers `finalize(through:)` for the
case where you want to keep going:

```
func finalize(through:)                      // finalize, keep going
func finalizeAndFinishThroughEndOfInput()    // finalize and finish
```

A finished analyzer still accepts `start(inputSequence:)` without throwing. It
simply never emits a result, and the module's `results` sequence has already
terminated, so the consuming loop exits instantly. Every failure path is
silent.

Fix: rebuild the analyzer *and* its transcriber module per dictation, keeping
only asset installation and format resolution in `prepare()`. Build the next
session at the end of the previous one so the key press pays nothing.

**The general lesson is about the test, not the fix.** A test that transcribes
one file passes against the broken code. The bug only exists on the *second*
use, so the harness had to reuse one `Transcriber` across many files —
`spoke-eval --audio-dir`. When a bug is about reuse, exercising the thing once
is not a test.

### Bonus: what real transcripts actually look like

Running the whole fixture set through confirmed the earlier finding and added
detail. `SpeechTranscriber` output is already punctuated and capitalised, and
it makes its own choices the polisher then inherits:

| spoken | transcribed |
|---|---|
| "second option" | "2nd option" |
| "SpokeKit" | "spell kid" |
| "The Victorian period…" | "Victorian period…" (dropped the article) |

"spell kid" is worth noting: the vocabulary feature assumes the polisher can
recover a known term from a near-miss, but the transcriber can land far enough
away that there is nothing recognisable to correct. Vocabulary may need to
reach the *transcriber* (via `SFCustomLanguageModelData`) rather than only the
polisher's prompt.

---

## 2026-08-18 — The hardened runtime gates the microphone, silently

Symptom: no microphone prompt, and Spoke absent from System Settings ›
Privacy & Security › Microphone entirely — not listed and switched off,
*absent*. No TCC log entries either.

Two separate causes, found in order:

**1. One permission hiding another.** `bootstrap()` checked Accessibility
first and returned early, so `AVCaptureDevice.requestAccess(for: .audio)` was
never reached. macOS lists an app in that pane only once it has asked, so an
app that never asks is invisible there. Fixed by requesting the microphone
unconditionally and reporting all missing permissions together
(`StartupGate`).

**2. The missing entitlement.** With `ENABLE_HARDENED_RUNTIME = YES` and no
entitlements file, the app was signed with only `get-task-allow`. The
hardened runtime blocks microphone access unless
**`com.apple.security.device.audio-input`** is present — and it blocks it
*before TCC is consulted*, so `requestAccess` returns `false` immediately with
no prompt, no pane entry, and nothing in the TCC log.

`NSMicrophoneUsageDescription` in Info.plist is **necessary but not
sufficient**. The usage string controls what the prompt says; the entitlement
controls whether there is a prompt at all. Sandbox-off does not exempt you —
this is the hardened runtime, which is a separate mechanism.

Diagnostic worth remembering:

```bash
codesign -d --entitlements - --xml YourApp.app | plutil -p -
```

If the only entry is `get-task-allow`, the app has no resource entitlements at
all, whatever the Info.plist says.

---

## 2026-08-18 — What the on-device model will and won't do

Measured with `spoke-eval` (see [ADR-0004](../decisions/adr/0004-evaluation-harness-seam.md)),
Apple's ~3B `SystemLanguageModel`, English, macOS 26.5.

### A single run is not a measurement

The most expensive lesson of the day, learned twice.

A prompt edit made one corpus case pass. It scored **0 of 5** when repeated.
Another edit was judged useless and reverted — comparing a one-run baseline
against a three-run result, which is not a comparison at all. Re-measured
properly it had nearly **doubled** the pass rate.

The model's output varies materially between identical calls: capitalisation
appears and disappears, punctuation comes and goes, whole clauses get reworded.
`--repeat 5` is the floor for believing anything. A case passing 3 of 5 does not
mean the instruction is *nearly* working; it means the instruction is
underspecified and the model is guessing.

### Some rules it will simply not follow

Terminal punctuation was the clearest case. The model punctuated *between*
sentences and left the last one open, on 5 of 5 runs for several inputs. It
survived:

1. An explicit instruction ("Every sentence ends with a full stop … including
   the last sentence in the text")
2. The same constraint repeated in the `@Guide` description

Spoken formatting commands behaved the same way — "period" and "new paragraph"
came back transcribed as words, capitalised into sentences of their own, 5 of 5.

### The rule that came out of it

> If a transformation is mechanical and has a right answer, do not ask the
> model. Do it in code.

Terminal punctuation moved to `SentenceTerminator`
([ADR-0005](../decisions/adr/0005-deterministic-sentence-termination.md)):
**87%** of runs passing, up from 47%. Structural commands moved to
`SpokenCommands` ([GDR-0003](../decisions/gdr/0003-structural-spoken-commands-only.md)):
**98%**.

The corollary matters as much. Context is scarce on a small model, and an
instruction it ignores is not free — it dilutes attention from the rules it
*can* follow. Every rule moved into code made the remaining prompt better.

### Where a constraint is stated changes how hard it lands

`@Guide(description:)` sits at the generation site and binds tighter than the
session `instructions`. It still wasn't enough for terminal punctuation, but
the ordering is real and worth reaching for before giving up on a prompt.

### Design deterministic passes as allowlists

`SentenceTerminator` appends a full stop only when the deciding character is a
letter or a digit. Written as a blocklist it would have needed to anticipate
ellipses, clause marks, dashes, emoji, and closing brackets — and would have
shipped "sounds good 👍." because nobody thinks of emoji up front. The
allowlist never had to.

### Ambiguity is a product decision, not a prompt problem

"Period" is an ordinary English word. No prompt resolves *the Victorian period*
versus *end this sentence*, and neither does a find-and-replace. The fix was to
notice the feature was **redundant**: Apple's dictation needs spoken punctuation
because it has no cleanup layer; Spoke has one. Dropping it removed the
ambiguity entirely rather than managing it.

---

## 2026-08-18 — Real transcripts already have punctuation

`SpeechTranscriber` output for clean speech comes back capitalised and
punctuated:

```
Okay, so the build is failing on CI. It looks like a signing issue.
I will take a look after lunch.
```

That is the **raw** transcript, before the polisher. The hand-written corpus
assumed unpunctuated input and was therefore testing a situation that partly
doesn't arise. Corpus inputs should be regenerated from real transcriber output
rather than imagined. (Not yet done.)

Caveat: that sample is synthesised speech via `say`. Real dictation with
hesitation and trailing-off may well transcribe differently.

---

## 2026-08-18 — AVAudioFile fails at EOF instead of returning zero frames

`read(into:frameCount:)` does **not** return a zero-length buffer when the read
head reaches the end of the file. It fails — and fails without populating the
error pointer, so Swift surfaces `Foundation._GenericObjCError.nilError`, which
carries no information whatsoever.

The fix is to bound the loop by `file.length` and never read at EOF:

```swift
while file.framePosition < file.length {
    let wanted = AVAudioFrameCount(min(Int64(chunk), file.length - file.framePosition))
    …
}
```

Pinned by a regression test using a file whose length is deliberately not a
whole number of chunks.

---

## 2026-08-18 — Continuity microphone and hold-to-talk

The Mac Studio has **no built-in microphone**. An iPhone works as one over
Continuity (Settings › General › AirPlay & Continuity › Continuity Camera; the
phone must be nearby and locked). Continuity needs **Wi-Fi enabled even on a
wired Mac** — easy to miss on a desktop plugged into Ethernet.

The caveat for this app specifically: the link has a wake-up cost. Spoke starts
`AVAudioEngine` on the hotkey press, so a cold Continuity device can clip the
first word, or report a 0 sample rate and trip
`AudioCaptureError.noInputDevice`. A USB cable, or a real USB microphone, avoids
it. Worth remembering before debugging a bug that isn't in our code.
