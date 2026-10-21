# 0026 — Apple Watch: the to-do key on the wrist, the Library at a glance, and no model needed there

- **Status:** Accepted (implementation pending)
- **Date:** 2026-10-18
- **Builds on:** [GDR-0023](0023-the-library.md) (decision 2: the iPhone is
  a companion, not a port), [GDR-0016](0016-todos-by-voice-into-reminders.md)
  (to-dos into Reminders, read back by voice),
  [GDR-0008](0008-voice-in-and-out.md) (voice out),
  [GDR-0002](0002-english-first-macos-only.md) (why dictation stays on the
  Mac).

## Context

GDR-0023 made the iPhone a companion: the Library in your pocket, practice,
the word of the day. It said nothing about the wrist, and the wrist is where
two of Timbre's gestures want to be. The to-do key (GDR-0016) — hold, say
it, it is in Reminders — is a thing you do while walking, not at a desk. And
a word you have just heard is banked best in the three seconds before it is
forgotten, which is a raise of the wrist, not a trip to a Mac.

The platform was checked, not assumed. In the watchOS 27 SDK on the
development Mac: EventKit, WatchConnectivity, AppIntents, WidgetKit and
AVFAudio are present. `Speech` — and with it `SpeechAnalyzer` — is not.
FoundationModels ships in the SDK, but whether the model is eligible on
Watch hardware is unknown until it runs on one. On iPhone the on-device
model needs Apple Intelligence (iPhone 15 Pro and later); an older iPhone
has none. Hugo will test on all four: an iPhone with the model, one without,
an Apple Watch Ultra (Action Button) and a Series 9 or later (Double Tap, no
Action Button). Each of those is therefore a real user, not a hypothetical.

## Decision

**Timbre ships on Apple Watch as part of the companion, and nothing on the
wrist needs the model.**

On the wrist:

- **The to-do key.** The Action Button on an Ultra, Double Tap on a Series 9
  or later, or the app's own button: say the to-do, and it lands in the
  Timbre list in Reminders with the date read by the same deterministic
  detector as on the Mac (GDR-0016). A haptic confirms. A tap reads today's
  list back in the chosen voice. This works with no phone in range and no
  model: the detector is Foundation and the store is EventKit, both on the
  Watch.
- **The word of the day at a glance.** A complication and a Smart Stack
  card: the word, a tap for the meaning, and the day's state — met,
  practised, or waiting (GDR-0027).
- **Spell it** (GDR-0023, decision 5): the meaning shown, the word said and
  spelled, checked deterministically from the system dictation's text.
- **Heard a word.** Raise the wrist, say it, and it is in the Library with
  provenance: the Watch, the day, the time. The meaning fills in on the
  phone or the Mac.

The rules that make the degraded cases designed rather than discovered:

- **Deterministic on the wrist, the model elsewhere.** The Watch's speech
  input is the system's dictation, which returns text; `SpeechAnalyzer` is
  not on the platform, so there is no streaming, no live result and no
  vocabulary bias there. Anything that needs the model — Say it, an example
  sentence, a verdict — is done on the phone or the Mac and arrives by sync.
  The Watch says *waiting for your phone* rather than pretending.
- **An iPhone without Apple Intelligence** shows the Library, the word of
  the day and Spell it. Say it is unavailable there, labelled as such, and
  model-written lines arrive from a device that has the model.
- **Zero network requests from the Watch binary, as from every other.**
  Watch to phone is WatchConnectivity; the Library syncs by iCloud
  (GDR-0023, decision 1). Both are Apple's transports between the user's own
  devices.
- **No dictation into other apps and no command mode, on either device.**
  GDR-0002's reasons stand; GDR-0023 said so for the phone and this record
  says so for the wrist.

## Consequences

- GDR-0002's index entry now reads: *"no iOS app" superseded by 0023 and
  0026; dictation stays macOS-only.* The record itself stays as written.
- The Watch app is a target of the companion's project, importing
  `TimbreCore` alone (GDR-0023, decision 4). The to-do parser moves to Core
  with the Library, because the wrist runs it without TimbreKit.
- Distribution for iPhone and Watch is the App Store — review, a privacy
  label that says *no data collected*, TestFlight — while the Mac stays
  Developer ID and direct (ADR-0010, GDR-0013). Two paths, one team, one
  claim.
- Memory, battery and whether FoundationModels answers on a Watch are
  measured on hardware before any copy promises them. If the model does run
  there, the rule above still stands until a drill's corpus proves it should
  not.
- The phases (product map §7) gain a step after the iPhone: the Watch, with
  the to-do key first, because it needs nothing new.

## Alternatives considered

- **The Watch as a remote microphone for the Mac:** rejected; the Mac is not
  where the user is when the wrist is the right surface, and audio between
  devices is a stream to maintain for a gesture that needs only text.
- **Skip the Watch; the phone is enough:** rejected; the to-do key's value is
  capture at the moment of the thought (GDR-0016), and the moment is on the
  wrist.
- **Run the model on the Watch where available:** deferred; not until it is
  seen to answer on hardware, and never for the to-do key, which must work in
  a tunnel.
