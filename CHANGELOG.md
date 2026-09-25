# Changelog

Notable changes to Timbre (called *Spoke* through v0.1.1). Format follows [Keep a Changelog](https://keepachangelog.com);
versioning is [Semantic Versioning](https://semver.org).

`MARKETING_VERSION` in `apps/Timbre/Config/Shared.xcconfig` is the source of
truth for the app's version; a release tag must match it. `tools/release.sh`
turns the section for that version into the release notes shown in the app.

## [Unreleased]

### Added
- **Words appear as you speak.** Confirmed words are typed into the app
  while you are still talking, a sentence or so behind your voice, and the
  cleanup replaces them the moment you let go. The pill now shows only the
  words still being heard. Off in Settings › General if you would rather
  keep everything in the pill until release. Where an app cannot be read
  back — Terminal, secure fields — the pill-then-paste flow remains.
- **An icon.** The waveform from the website's favicon — four bars, the
  shape of a voice — on a charcoal tile, in the retro colours. Timbre had
  shipped with Xcode's placeholder until now.
- **A disk image.** The download is now a `.dmg` with an Applications
  folder to drag Timbre onto; the zip remains for updates and for anyone
  who prefers it.
- **A usage count in Settings** — words dictated, dictations, commands,
  to-dos and readings, this week and all time. Stored in this Mac's
  preferences and nowhere else.
- **To-dos by voice.** Hold right Command with nothing selected and say it —
  "call the dentist Thursday" — and it lands in a Timbre list in Apple's
  Reminders, with the date read on your Mac, so it's on your iPhone too. Tap
  left Option with nothing selected to hear the list. Pick any list in
  Settings.
- **Plain.** A fourth command: hold right Command on machine-sounding or
  corporate text and say "plain" to get what it actually says, in your
  own words.
- **Fix without Apple Intelligence.** On a Mac without the on-device model,
  fix still corrects spelling with macOS's own spell checker, leaving names
  and your taught words alone.

### Fixed
- Fix, shorten and plain no longer touch Slack mentions and channels, links,
  email addresses, dates, times, units, versions or abbreviations like
  "e.g." — they come back exactly as they were.
- Fixing a single selected word keeps its case: "teh" becomes "the", not
  "The".

## [0.3.1] — 2026-09-25

### Changed
- **Cleanup is now deterministic.** The same words get the same cleanup
  every time; the corpus passes 11 of 11 across five repeats with one
  output per case.
- **Sentences always start with a capital.** Applied as a rule after the
  model, like the final full stop, because the model left short casual
  sentences lowercase. Words with their own casing (iPhone, macOS) and
  abbreviations (e.g., a.m.) are left alone.

## [0.3.0] — 2026-09-24

### Added
- **Command mode.** Select text, hold right Command, and say fix, explain or
  shorten — it acts the moment it hears the word. Say nothing and release
  to fix. Explain shows a card and never touches your text; fix and shorten
  replace the selection, and Command-Z puts it back.
- **Definitions.** Teach Timbre your acronyms in Settings › Dictionary. A
  defined term is explained from your definition, and every card says
  whether its answer came from your dictionary or the on-device model.
- **Corrections.** When Timbre keeps hearing a phrase wrong, teach it what
  you meant once: "timber kit" becomes "TimbreKit" every time.
- **Updates.** Check for Updates in the menu, and an optional daily check,
  off by default. It fetches one small version file from Timbre's own
  website and sends nothing about you. Installing checks that the download
  is Timbre, signed by its developer and notarized by Apple, before it
  replaces anything.

### Changed
- Settings is organised into General, Dictionary, Reading and Privacy.
- Timbre is signed by its developer's renewed Apple team. Coming from 0.2.0,
  macOS asks for Accessibility once more: remove the old Timbre entry and
  add the new one.

### Fixed
- A speech session could be started while the previous one was still
  warming up, and then hear nothing.

## [0.2.0] — 2026-08-21

### Changed
- **The app is now called Timbre** (GDR-0009). "Spoke" read as bicycle
  hardware; the obvious replacements collided with Apple's own "Spoken
  Content" feature and with existing Mac dictation apps. Timbre is the
  character that makes a voice recognisably someone's own.
  The bundle identifier changed, so **Microphone and Accessibility must be
  granted again**, and captured dictations stay behind in
  `~/Library/Application Support/Spoke/`.

### Added
- **Read aloud** (GDR-0008): select text anywhere and tap left Option to
  hear it, tap again to speed up, hold to stop. On-device voices; Timbre
  picks the best installed and flags in Settings when only basic ones exist.
- Adaptive pre-roll so a cold Bluetooth audio route doesn't swallow the
  first words, mirroring the microphone warm-up fix.

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

[Unreleased]: https://github.com/ChaliceForAuri/Spoke/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ChaliceForAuri/Timbre/releases/tag/v0.2.0
[0.1.1]: https://github.com/ChaliceForAuri/Spoke/releases/tag/v0.1.1
[0.1.0]: https://github.com/ChaliceForAuri/Spoke/releases/tag/v0.1.0
