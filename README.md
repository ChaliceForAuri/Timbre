# Timbre

A free, fully-local dictation app for macOS. Hold right-Option, speak,
release — cleaned-up text appears in whatever app you're using.

Everything runs on-device: transcription on Apple's `SpeechAnalyzer`, cleanup
on the `FoundationModels` on-device LLM. No account, no network, no
subscription. See [GDR-0001](docs/decisions/gdr/0001-local-only-free-no-account.md)
for why that's the whole point.

## Requirements

- macOS 26.0+ on Apple Silicon, with Apple Intelligence enabled
  (System Settings › Apple Intelligence & Siri)
- Xcode 26+ to build

## Building

```bash
# The pipeline library + tests (fast, no app launch):
cd packages/TimbreKit && swift test

# The app:
xcodebuild -project apps/Timbre/Timbre.xcodeproj -scheme Timbre build
```

Or open `apps/Timbre/Timbre.xcodeproj` in Xcode and ⌘R.

First run: grant Microphone when prompted. For Accessibility, approve the
app in System Settings › Privacy & Security › Accessibility, then **quit and
relaunch** — the trusted state is only read at launch.

## Repository map

```
apps/Timbre/        Xcode app: scenes and glue views, nothing else
packages/TimbreKit/ The pipeline: audio → transcription → polish → insertion
docs/decisions/    ADRs (architecture) and GDRs (product) — start here
docs/learning/     Timbre University: macOS development from first principles
web/               Website (placeholder until the app ships)
```

The pipeline, in one breath: `HotkeyMonitor` emits press/release events →
`DictationController` starts `AudioCapture` (mic → `AnalyzerInput` stream) →
`Transcriber` (on-device ASR) streams live text into the `OverlayController`
pill → on release, `TextPolisher` (on-device LLM) cleans the transcript →
`TextInserter` pastes it where the user was typing.

## Contributing to decisions

Significant choices are recorded in `docs/decisions/` — architecture in
`adr/`, product in `gdr/`. The records are immutable; to reverse one, write
a new record that supersedes it. The index and process live in
[docs/decisions/README.md](docs/decisions/README.md).
