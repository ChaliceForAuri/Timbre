# Changelog

Notable changes to Spoke. Format follows [Keep a Changelog](https://keepachangelog.com);
versioning is [Semantic Versioning](https://semver.org).

`MARKETING_VERSION` in `apps/Spoke/Config/Shared.xcconfig` is the source of
truth for the app's version; a release tag must match it.

## [Unreleased]

## [0.1.1] — 2026-08-20

### Fixed
- "Settings…" did nothing: `SettingsLink` opens the window without
  activating the app, and a menu-bar app is never active, so the window
  appeared behind everything. The app now activates itself first. Found
  within a day of running on three Macs — the first bug caught by
  distribution.

## [0.1.0] — 2026-08-19

First release. Everything below shipped between 2026-08-15 and today.

### Added
- Dictation pipeline: hold right ⌥, speak, release — cleaned-up text is pasted
  into whatever app has focus. Transcription via `SpeechAnalyzer`, cleanup via
  the on-device `SystemLanguageModel`.
- `spoke-eval`, an evaluation harness measuring the polisher against a fixed
  corpus (ADR-0004). Supports `--repeat` for stochastic output, `--stream` for
  partial-result timing, and `--audio-dir` for transcriber reuse.
- Opt-in local dictation capture for building real evaluation fixtures
  (GDR-0004).

### Added
- Per-dictation timing records (mic start, first audio, transcript, polish)
  in the capture log, so latency work is measured rather than felt.

### Fixed
- Speaking immediately after the hotkey press lost the first words. The
  microphone now opens before anything else on the press, the analyzer is
  pre-warmed at launch and between dictations, and the pill says "Waking the
  mic…" until the first non-silent buffer arrives — the flip to "Listening…"
  is a true go signal. On Bluetooth headsets the wake itself remains
  hardware-bound (issue #4).
- A Release-only crash (SIGBUS) in the hotkey event path: the monitor
  closures inherited MainActor isolation, and the runtime executor check
  Swift compiled into every key event dereferenced a stale pointer inside
  AppKit's event dispatch. The event path now runs with no isolation
  machinery at all (ADR-0007).
- Dictating with no microphone connected hung forever at "Cleaning up…";
  the finish path is now un-hangable (immediate refusal, silence detection,
  and a watchdog around finalization).
- The overlay could appear unpositioned in the bottom-left corner: a zero
  first-pass layout size skipped placement entirely. It now always places —
  under the caret when the app reveals it, otherwise as a bottom-center HUD.
  The mouse fallback is gone; pointer position is unrelated to typing.
- Speech sessions are rebuilt per dictation; previously only the first
  dictation produced any text (ADR-0006).
- The microphone is requested unconditionally, and the hardened runtime's
  `com.apple.security.device.audio-input` entitlement is present — without it
  macOS blocked the microphone before TCC was ever consulted.
- The overlay no longer re-sets its own frame on every audio buffer, which
  flickered and could clip the live transcript out of view.

[Unreleased]: https://github.com/ChaliceForAuri/Spoke/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/ChaliceForAuri/Spoke/releases/tag/v0.1.1
[0.1.0]: https://github.com/ChaliceForAuri/Spoke/releases/tag/v0.1.0
