# Spoke

A free, fully-local dictation app for macOS. Hold right-Option, speak, release —
cleaned-up text appears in whatever app you're using.

Built as a replacement for Wispr Flow ($15/month, cloud-only). Everything here
runs on-device: no account, no network, no subscription.

## Requirements

- macOS 26.0+ (for `SpeechAnalyzer` and `FoundationModels`)
- Apple Silicon, Apple Intelligence enabled
- Xcode 26+

## Architecture

Single pipeline, triggered by a held hotkey:

```
HotkeyMonitor (right ⌥ down)
  └─> DictationController.beginListening()
        ├─> OverlayController.show()      floating pill near the caret
        ├─> Transcriber.startDictation()  Apple on-device streaming ASR
        └─> AudioCapture.start()          mic → PCM buffers → transcriber
                                          └─> RMS levels → overlay waveform

HotkeyMonitor (right ⌥ up)
  └─> DictationController.endListening()
        ├─> Transcriber.finishDictation() flush + final transcript
        ├─> TextPolisher.polish()         on-device LLM cleanup
        ├─> OverlayController.hide()
        └─> TextInserter.insert()         clipboard + synthetic ⌘V
```

### Files

| File | Responsibility |
|---|---|
| `SpokeApp.swift` | `@main`, `MenuBarExtra`, settings window, macOS-version gate |
| `DictationController.swift` | Orchestrates the pipeline. Start here. |
| `AudioCapture.swift` | `AVAudioEngine` mic tap, format conversion, RMS metering |
| `Transcriber.swift` | `SpeechAnalyzer` / `SpeechTranscriber` actor wrapper |
| `TextPolisher.swift` | Foundation Models cleanup. **Core product value.** |
| `TextInserter.swift` | Pasteboard save → set → ⌘V → restore |
| `HotkeyMonitor.swift` | `NSEvent` flagsChanged monitors for right-Option |
| `OverlayController.swift` | Non-activating `NSPanel`, caret positioning |
| `OverlayView.swift` | SwiftUI content for the overlay pill |

## Conventions

- **Swift 5 language mode** while learning. Strict Swift 6 concurrency rejects
  passing `AVAudioPCMBuffer` across actor boundaries; revisit later.
- **Never break focus.** Any new window must be a `.nonactivatingPanel` shown
  with `orderFrontRegardless()`. `makeKeyAndOrderFront` breaks the paste target.
- **Always paste something.** `TextPolisher` falls back to the raw transcript on
  any model failure. The user must never lose an utterance.
- **Audio-thread callbacks touch no UI.** Hop to `@MainActor` via `Task`.
- No third-party dependencies. Everything is Apple frameworks. Keep it that way
  unless there's a compelling reason.

## Permissions (must be configured in the Xcode target)

- App Sandbox: **OFF** (blocks synthetic `⌘V` into other apps)
- `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`
- `LSUIElement` = YES (menu bar app, no Dock icon)
- Accessibility permission granted manually; **only read at launch**, so the
  app must be restarted after granting.

## Known gaps / non-goals

- **English-first.** Apple's on-device model is weaker at other languages and
  has no real code-switching. Not competing with Wispr on 100+ languages.
- **Mac only.** iOS can't replace system dictation; a keyboard extension is the
  only route and it's memory-constrained.
- **No sync.** Deliberate — it's the privacy story.

## Roadmap

1. Tune the `TextPolisher` prompt against real dictation. Highest leverage.
2. Auto-learn vocabulary: diff user edits made shortly after insertion.
3. Per-app tone profiles (the app name is already passed to the polisher).
4. Command mode: select text + different hotkey → "make this shorter".
5. Notarize and distribute directly.

## Working on this

Build and run: open in Xcode, ⌘R. There is no CLI test suite yet.
To check it compiles without opening Xcode:

```bash
xcodebuild -scheme Spoke -destination 'platform=macOS' build
```
