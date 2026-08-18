# Spoke

A free, fully-local dictation app for macOS. Hold right-Option, speak,
release — cleaned-up text appears in whatever app you're using. Everything
runs on-device: no account, no network, no subscription (GDR-0001).

## Requirements

- macOS 26.0+, Apple Silicon, Apple Intelligence enabled
- Xcode 26+

## Repository layout

Monorepo (ADR-0002): the app logic is a Swift package; the Xcode target is a
thin shell of scenes and glue views.

```
apps/Spoke/          Xcode project. Config/*.xcconfig holds every build
                     setting; the pbxproj uses synchronized folders and
                     should almost never change.
packages/SpokeKit/   The entire pipeline + tests. Work happens here.
docs/decisions/      ADRs (constrain a file) and GDRs (constrain the
                     product). Immutable; supersede, don't edit.
docs/learning/       Spoke University + historical planning notes.
web/                 Website placeholder. Toolchain must stay inside web/.
```

## Build and test

```bash
# Fast loop — the package is where the logic lives:
swift test --package-path packages/SpokeKit

# Measure the polisher against the fixed corpus (ADR-0004). The model is
# stochastic: never judge a prompt change on a single run.
cd packages/SpokeKit && swift run spoke-eval Fixtures/corpus.json --repeat 5

# Regenerate audio fixtures (no microphone needed — uses `say`):
tools/make-audio-fixtures.sh

# Lint (config in .swift-format, toolchain-bundled tool):
xcrun swift-format lint --strict --recursive packages apps/Spoke/Sources

# Full app:
xcodebuild -project apps/Spoke/Spoke.xcodeproj -scheme Spoke -destination 'platform=macOS' build
```

Or open `apps/Spoke/Spoke.xcodeproj` and ⌘R. Signing is ad-hoc by default;
for a stable identity (keeps the Accessibility grant across rebuilds), copy
`apps/Spoke/Config/Local.xcconfig.template` to `Local.xcconfig` and set your
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
        ├─> TextPolisher    FoundationModels cleanup. Core product value.
        └─> TextInserter    pasteboard snapshot → set → synthetic ⌘V → restore
```

Public API surface of SpokeKit is `DictationController` (+ its `Status`);
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
- `INFOPLIST_KEY_*` carries mic + speech strings and `LSUIElement`
- Accessibility granted manually; **only read at launch** — restart the app
  after granting

## Decision records

Before changing architecture or product direction, check
`docs/decisions/README.md` (the index) and add a record when the decision
constrains future work. ADR = constrains a file; GDR = constrains the
product. Records are immutable — supersede instead of editing.

## Known gaps / non-goals (GDR-0002)

- English-first: Apple's on-device model is weaker elsewhere; not chasing it
- macOS-only: iOS can't replace system dictation
- No sync: deliberate, it's the privacy story

## Roadmap

1. Tune the `TextPolisher` instructions. Highest leverage. Measure with
   `spoke-eval` — see ADR-0004, and never trust a single run.
2. Auto-learn vocabulary: diff user edits made shortly after insertion.
3. Per-app tone profiles (the app name is already passed to the polisher).
4. Command mode: select text + different hotkey → "make this shorter".
5. Notarize and distribute directly; build out `web/`.
