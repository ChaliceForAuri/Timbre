# Timbre

A free, fully-local voice interface for macOS. Hold right-Option, speak,
release — cleaned-up text appears in whatever app you're using. Tap
left-Option to hear a selection read aloud (GDR-0008). Hold right-Command on
a selection and say fix, explain or shorten (GDR-0012). Everything runs
on-device: no account, no network, no subscription (GDR-0001).

## Requirements

- macOS 26.0+, Apple Silicon, Apple Intelligence enabled
- Xcode 26+

## Repository layout

Monorepo (ADR-0002): the app logic is a Swift package; the Xcode target is a
thin shell of scenes and glue views.

```
apps/Timbre/          Xcode project. Config/*.xcconfig holds every build
                     setting; the pbxproj uses synchronized folders and
                     should almost never change.
packages/TimbreKit/   The entire pipeline + tests. Work happens here.
docs/decisions/      ADRs (constrain a file) and GDRs (constrain the
                     product). Immutable; supersede, don't edit.
docs/learning/       Timbre University + historical planning notes.
web/                 Website + Backstage lab: SvelteKit/Supabase/Vercel
                     (GDR-0007, docs/design/backstage.md). Node toolchain
                     must stay inside web/. The app NEVER phones home —
                     data flows dev side → lab only (GDR-0006).
```

## Build and test

```bash
# Fast loop — the package is where the logic lives:
swift test --package-path packages/TimbreKit

# Measure the polisher against the fixed corpus (ADR-0004). The model is
# stochastic: never judge a prompt change on a single run.
cd packages/TimbreKit && swift run timbre-eval Fixtures/corpus.json --repeat 5

# Same discipline for command mode's fix / explain / shorten (GDR-0012):
swift run timbre-eval --commands Fixtures/commands.json --repeat 5

# When each spoken command is recognised live, and that the session after an
# abandon still works (GDR-0014). Pad each clip with the silence of a held key:
#   say -o dir/explain.aiff "explain [[slnc 2000]]"
swift run timbre-eval --live-commands <dir> --check Fixtures/audio/03-run-on.aiff

# Regenerate audio fixtures (no microphone needed — uses `say`):
tools/make-audio-fixtures.sh

# Audio → transcript, every fixture through one Transcriber (ADR-0006), each
# biased with its corpus case's taught vocabulary; reports how many taught
# terms came back verbatim (ADR-0008). Fixtures are gitignored: generate them
# first with tools/make-audio-fixtures.sh.
swift run timbre-eval --audio-dir Fixtures/audio --corpus Fixtures/corpus.json

# Real dictation → corpus. Turn capture on in Settings first (GDR-0004),
# dictate, then import. Checks are left empty for you to fill in.
swift run timbre-eval --import ~/Library/Application\ Support/Timbre/dictations.jsonl \
  --out Fixtures/real-corpus.json

# See partial results arrive at microphone pace:
swift run timbre-eval --stream Fixtures/audio/03-run-on.aiff

# Lint (config in .swift-format, toolchain-bundled tool):
xcrun swift-format lint --strict --recursive packages apps/Timbre/Sources

# Full app:
xcodebuild -project apps/Timbre/Timbre.xcodeproj -scheme Timbre -destination 'platform=macOS' build

# Daily driver: build Release and install to /Applications (grants carry over):
tools/install.sh

# Notarized zip for any Mac (one-time setup inside the script):
tools/release.sh
```

Or open `apps/Timbre/Timbre.xcodeproj` and ⌘R. Signing is ad-hoc by default;
for a stable identity (keeps the Accessibility grant across rebuilds), copy
`apps/Timbre/Config/Local.xcconfig.template` to `Local.xcconfig` and set your
team.

## Architecture

Single pipeline, one dictation at a time:

```
HotkeyMonitor          right ⌥ via device flag bit → AsyncStream<HotkeyEvent>
  └─> DictationController   consumes events in ONE task — that's what
        │                   serializes begin/end (no press/release race)
        ├─> AudioCapture    mic tap → converts ON the audio thread →
        │                   AsyncStream<AnalyzerInput> + AsyncStream<Float> levels
        ├─> Transcriber     actor; SpeechAnalyzer consumes the input stream,
        │                   returns a stream of transcript snapshots
        ├─> OverlayController  non-activating panel near the caret
        ├─> TextPolisher    corrections → spoken commands → FoundationModels
        │                   cleanup → terminator. Core product value.
        └─> TextInserter    pasteboard snapshot → set → synthetic ⌘V → restore

Two gestures work on a selection instead, through the same controller:
  left ⌥ tap    SelectionReader → SpeechReader (read aloud, GDR-0008)
  right ⌘ hold  arm 350 ms → same mic + Transcriber → the first live result
                holding a command word fires it (CommandHold, GDR-0014) →
                TextTransformer → paste over the selection, or a streamed
                explanation card (command mode, GDR-0012)
```

Public API surface of TimbreKit is `DictationController` (+ its `Status`);
everything else is internal. Keep it that way.

## Conventions

- **Swift 6 language mode, complete concurrency, everywhere** (ADR-0001).
  Default MainActor isolation + approachable-concurrency features, matching
  the Xcode 26 template. Concurrency is opted into (`actor`, `nonisolated`),
  never out of. No new `@unchecked Sendable` without a comment proving the
  invariant (the only existing one is `AudioTapProcessor`).
- **Audio crosses isolation as `AnalyzerInput`, never `AVAudioPCMBuffer`.**
  Conversion happens inside the tap. On stop, `BufferConverter.drain(into:)`
  must be called — the converter holds ~100 ms of tail audio (the user's
  last word) that is otherwise silently clipped.
- **Never break focus.** Any new window must be a `.nonactivatingPanel`
  shown with `orderFrontRegardless()`. `makeKeyAndOrderFront` breaks the
  paste target.
- **Always paste something.** `TextPolisher` falls back to the raw
  transcript on any failure; `TextInserter` falls back to leaving text on
  the pasteboard when Accessibility is missing. The user never loses an
  utterance.
- **Pasted text always ends a sentence.** `SentenceTerminator` adds the final
  full stop deterministically as the last step of `polish`, on every path
  including the fallbacks (ADR-0005). The prompt must not ask the model for
  it — that was tried twice and failed 5 of 5 runs.
- **Taught corrections run first, deterministically.** `CorrectionTable`
  replaces each taught *heard* phrase with its *meant* text before spoken
  commands and the model (GDR-0011): whole phrase, case ignored, verbatim,
  never fuzzy. The polisher fixes "timbre kit" but not "timber kit" — one
  letter of phonetic distance — so that class of error lives here.
- **Command mode never guesses and never destroys** (GDR-0012). An
  unrecognised word does nothing and says what was heard; any model failure
  leaves the selection untouched — the inverse of the polisher's "always
  paste something". Explain answers from the user's taught definitions first
  and labels the card with its source: the model invents expansions for
  acronyms it does not know. Right ⌘ is a real shortcut key, so the mode *arms* after
  an uninterrupted 350 ms hold; the key/click watch that detects a shortcut
  exists only during that hold and never looks at the event.
- **Commands act on the word, not the release** (GDR-0014). The first live
  result containing a command word runs it, once; explain alone may fire on
  a partial ("Expl", "Acr") because it never touches text. After firing the
  speech session is *abandoned*, not finalized. Measure changes to this path
  with `swift run timbre-eval --live-commands <dir>`, which also checks the
  session after an abandon still transcribes (ADR-0006).
- **Commands decode greedily** (ADR-0009): same selection, same command,
  same result, and a corpus that measures instead of rolling dice. Fix uses
  guided generation without the schema in the prompt; shorten and explain
  generate plain text, because guided generation leaked its schema into
  explanations and copied every shorten input. The shorten prompt's shape —
  fenced text, instruction after it, a word budget — is all measurement;
  re-run `timbre-eval --commands` before touching it.
- **A speech session is single-use** (ADR-0006).
  `finalizeAndFinishThroughEndOfInput()` ends the `SpeechAnalyzer` for good
  and terminates the module's `results` sequence. `Transcriber` rebuilds both
  per dictation. Reusing them makes only the *first* dictation work, silently.
  Verify with `swift run timbre-eval --audio-dir Fixtures/audio` — one file
  passes against the broken code.
- **Caret lookup is IPC.** `CaretLocator.caretScreenRect()` is a synchronous
  round-trip into another process — once per dictation at overlay show,
  never per frame.
- Pure logic lives in small `nonisolated` types (`HoldDetector`,
  `TranscriptAccumulator`, `PolishGuardrail`…) with Swift Testing coverage.
  New behavior follows that pattern: extract the decision, test it.
- No third-party dependencies — Apple frameworks and toolchain tools only.
- Build settings belong in xcconfig files, never edited into the pbxproj.

## Permissions (already configured in xcconfig)

- App Sandbox **off** (blocks synthetic ⌘V — ADR-0003); hardened runtime on
- **`Timbre.entitlements` carries `com.apple.security.device.audio-input`.**
  The hardened runtime gates the mic behind it; the Info.plist usage string
  alone is not enough. Without it `requestAccess` returns false with no
  prompt and the app never appears in Privacy & Security › Microphone
- `INFOPLIST_KEY_*` carries mic + speech strings and `LSUIElement`
- Accessibility is granted manually (System Settings, `+` button). Timbre
  polls `AXIsProcessTrusted()` while blocked and retries startup on its own,
  so a relaunch should not be needed — but if the trusted state turns out to
  be cached per-process, relaunching is still the fallback
- **TCC entries embed the bundle identifier.** Changing
  `PRODUCT_BUNDLE_IDENTIFIER` orphans every existing grant: the toggle still
  shows in System Settings but no longer matches the binary. Remove the stale
  row with `-` and re-add

## Decision records

Before changing architecture or product direction, check
`docs/decisions/README.md` (the index) and add a record when the decision
constrains future work. ADR = constrains a file; GDR = constrains the
product. Records are immutable — supersede instead of editing.

## Known gaps / non-goals (GDR-0002)

- English-first: Apple's on-device model is weaker elsewhere; not chasing it
- macOS-only: iOS can't replace system dictation
- No sync of dictations, ever. The personal dictionary (taught words,
  acronyms) may sync via the user's own iCloud, opt-in and off by default
  (GDR-0010). The binary still makes zero network requests; system daemons
  do the syncing

## Roadmap

1. Tune the `TextPolisher` instructions. Highest leverage. Measure with
   `timbre-eval` — see ADR-0004, and never trust a single run.
2. Auto-learn vocabulary: offer a correction from the user's own edits made
   shortly after insertion. The transcriber cannot be taught — it ignores
   contextual strings and has no custom-model hook (ADR-0008) — so stable
   mis-hearings are fixed by the taught correction table (GDR-0011). What
   remains is teaching it without opening Settings.
3. Per-app tone profiles (the app name is already passed to the polisher).
4. Command mode shipped with three verbs (GDR-0012). Next: a taught acronym
   dictionary answering "explain" before the model does; more verbs only if
   each comes with a guardrail that can score it.
5. Notarize and distribute directly; build Backstage per
   `docs/design/backstage.md` (phases 1-6, University ships first).
