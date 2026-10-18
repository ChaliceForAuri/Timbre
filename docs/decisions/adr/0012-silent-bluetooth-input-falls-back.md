# 0012 — A silent Bluetooth input falls back to the built-in microphone

- **Status:** Accepted
- **Date:** 2026-10-17
- **Constrains:** `packages/TimbreKit/Sources/TimbreKit/Audio/AudioCapture.swift`, `InputDevices.swift`, `InputFallback.swift`, the capture watchdog in `DictationController`
- **Builds on:** issue #4 (the Bluetooth wake), the no-audio guard in `endListening`

## Context

AirPods connected to a Mac and streaming music from an iPhone stay the Mac's default input and deliver exact digital zeros: one microphone link, held by the other device. Hugo held the key, talked, and got "The microphone didn't deliver any audio" — correct, and useless. The guard that catches a dead route was built so Timbre never pastes into dead air; it was never meant to be the whole answer.

The same route delivers zeros while a headset merely wakes, for well under two seconds on every Mac measured so far (issue #4). The two cases are told apart by time.

## Decision

1. **After 2.5 s of perfect silence on a Bluetooth input, the capture moves to the Mac's built-in microphone** for the rest of that dictation, and the pill says "Using the Mac's mic". The analyzer keeps consuming the same input sequence and the pill the same levels; only the device behind them changes (`AudioCapture.switchInput(to:)`). Nothing restarts, nothing is lost: the headset had delivered nothing.
2. **Only a Bluetooth input falls back.** Wired and built-in inputs cannot be connected and silent in this way; a Mac with no built-in mic keeps the headset and the release path reports the silence as before.
3. **The rule is pure and tested** (`InputFallback.shouldFallBack`), and the switch is a timing in the capture log (`inputFallbackMs`), so the wait can be tuned from numbers.
4. **The fallback never changes the system's default input.** It selects the device on Timbre's own audio unit for one capture; the next hold opens the default again, which may be the headset, awake by then.

## Consequences

- A dictation into a busy headset costs 2.5 s and a visibly different microphone, instead of nothing.
- The wait is a constant to revisit if `firstAudioMs` on a waking headset is ever measured above it; the capture log is where that shows.
- The switch is a device property set on `AVAudioEngine`'s input unit between a stop and a start; Hugo's AirPods, playing from another device, are the test, and the capture log the proof.
