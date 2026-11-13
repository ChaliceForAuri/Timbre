# 0015 — Framework-bound code lives in a package per framework, with that framework's platforms

- **Status:** Accepted
- **Date:** 2026-10-18
- **Builds on:** [ADR-0013](0013-timbrecore-platform-neutral-package.md)
  (Core imports Foundation and Observation only; what needs a framework is a
  protocol in Core and an implementation beside the framework),
  [ADR-0002](0002-package-plus-shell-monorepo.md);
  [GDR-0023](../gdr/0023-the-library.md) and
  [GDR-0026](../gdr/0026-apple-watch-the-wrist-key.md) (what the companion
  runs).

## Context

The companion needs three things the Mac pipeline already has: capture and
on-device transcription for Spell it and Say it, reading aloud, and the
Timbre list in Reminders for the to-do key. The iPhone also needs the
on-device model for the card's example sentence and the drills' judges. All
of it lived in `TimbreKit`, whose platform is `macOS 26` alone and whose
imports include AppKit and the Accessibility API.

SwiftPM declares platforms per package, not per target. A package that
claims watchOS while one of its targets imports `Speech` — which watchOS
does not have — compiles until the day the Watch app links the wrong
product. The frameworks have different reaches: AVFAudio and Speech on the
Mac and the iPhone; FoundationModels on the Mac and the iPhone (and in the
watchOS SDK, with eligibility unproven, GDR-0026); EventKit on all three.

## Decision

**Code bound to a framework lives in a package named for what it does,
declaring exactly the platforms that framework has.** Three now, one more
to come:

```
packages/TimbreSpeech/      AVFAudio + Speech. AudioCapture, BufferConverter,
                            AudioLevel, Transcriber, TranscriptSnapshot,
                            AudioFileInput, ContextualVocabulary, SpeechReader,
                            VoiceCatalog, ReadingSpeed. macOS 26, iOS 26.
packages/TimbreModel/       FoundationModels. OnDeviceModel.availability, the
                            ExampleWriter; the drills' judges next. Depends on
                            TimbreCore for the guardrails. macOS 26, iOS 26.
packages/TimbreReminders/   EventKit. ReminderStore, TodoOrdering. Depends on
                            TimbreCore for Todo. macOS 26, iOS 26, watchOS 26.
packages/TimbreCloud/       CloudKit, when sync lands (GDR-0023 decision 1).
                            All three.
```

- **The platform list is the framework's reach, nothing more.** A package
  never claims a platform its import lacks.
- **`#if os(macOS)` is for a few lines of device plumbing, never a module.**
  `InputDevices` and `AudioCapture.switchInput(to:)` — the Core Audio HAL
  calls behind the Bluetooth fallback (ADR-0012) — are the documented
  exception inside TimbreSpeech. Everything else in a package builds on
  every platform it declares.
- **Each package exports what its consumers call and no more.** The Mac
  pipeline's `DictationController` and the harness are the consumers today;
  the companion tomorrow. Internals stay internal and are tested with
  `@testable import`.
- **One answer for the model's availability**: `OnDeviceModel.availability`
  in TimbreModel; the polisher delegates to it.
- **The harness stays in TimbreKit**, where the Mac pipeline is, and drives
  the packages through their public API (ADR-0004).
- **TimbreKit depends on all of them** and keeps only what touches a Mac:
  the hotkey, the overlay, insertion, the selection, the polisher and
  command mode, the pipeline that ties them together.

## Consequences

- Six packages, each with its own `Package.swift`, each copying the same
  Swift settings (ADR-0001). CI runs five test suites; nothing was lost in
  the move — TimbreKit's 209 tests became 169 there, 38 in TimbreSpeech and
  2 in TimbreModel, and TimbreReminders gained 2 for the ordering that was
  extracted from `openTodos`.
- The companion links TimbreCore, TimbreSpeech, TimbreModel and
  TimbreReminders on the iPhone, and TimbreCore and TimbreReminders on the
  Watch. The Watch cannot link TimbreSpeech or TimbreModel, by construction.
- The Mac app's project did not change: it links TimbreKit, which resolves
  the rest.
- A new framework means a new package, not a new target: the floor must be
  declared somewhere honest.

## Alternatives considered

- **One package, many targets:** rejected; one platform list for code with
  three different reaches.
- **Copy the speech stack into the iPhone app:** rejected; the pipeline's
  subtlest code (the converter's tail drain, single-use sessions) in two
  places.
- **Conditional compilation across TimbreKit:** rejected (ADR-0013); a
  package boundary is a floor the compiler enforces.
