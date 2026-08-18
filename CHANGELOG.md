# Changelog

Notable changes to Spoke. Format follows [Keep a Changelog](https://keepachangelog.com);
versioning is [Semantic Versioning](https://semver.org).

`MARKETING_VERSION` in `apps/Spoke/Config/Shared.xcconfig` is the source of
truth for the app's version; a release tag must match it.

## [Unreleased]

### Added
- Dictation pipeline: hold right ⌥, speak, release — cleaned-up text is pasted
  into whatever app has focus. Transcription via `SpeechAnalyzer`, cleanup via
  the on-device `SystemLanguageModel`.
- `spoke-eval`, an evaluation harness measuring the polisher against a fixed
  corpus (ADR-0004). Supports `--repeat` for stochastic output, `--stream` for
  partial-result timing, and `--audio-dir` for transcriber reuse.
- Opt-in local dictation capture for building real evaluation fixtures
  (GDR-0004).

### Fixed
- Speech sessions are rebuilt per dictation; previously only the first
  dictation produced any text (ADR-0006).
- The microphone is requested unconditionally, and the hardened runtime's
  `com.apple.security.device.audio-input` entitlement is present — without it
  macOS blocked the microphone before TCC was ever consulted.
- The overlay no longer re-sets its own frame on every audio buffer, which
  flickered and could clip the live transcript out of view.

[Unreleased]: https://github.com/ChaliceForAuri/Spoke
