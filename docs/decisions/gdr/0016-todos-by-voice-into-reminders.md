# 0016 — To-dos by voice, into Apple's Reminders

- **Status:** Accepted
- **Date:** 2026-09-25
- **Builds on:** [GDR-0012](0012-command-mode.md) (the right-⌘ hold),
  [GDR-0008](0008-voice-in-and-out.md) (voice out), and the reasoning of
  [GDR-0010](0010-optional-icloud-sync-of-personal-dictionary.md) — the
  system syncs, the binary stays silent.

## Context

Hugo asked for a personal to-do list, synchronised across his devices, as
the feature that would make Timbre part of his day — and said why: ADHD.
The value is not the list; it is catching the thought at the moment it
happens, by voice, without leaving the app he is in. Every existing to-do
app makes capture the expensive part.

Timbre is macOS-only (GDR-0002), so "on every device" cannot mean a Timbre
list of its own. And the binary makes no network requests (GDR-0006), so it
cannot mean a service of ours either.

## Decision

**Spoken to-dos go into Apple's Reminders.** It is on every device Hugo
owns, it already syncs through his own iCloud, it has Siri, widgets, a Watch
app and notifications, and none of that costs Timbre a network request:
macOS's own daemons do the syncing, exactly as GDR-0010 reasons for the
dictionary.

- **The gesture is the one that exists.** Hold right ⌘ with *nothing
  selected*, say the to-do, release. The pill says "Say a to-do…" instead of
  the command hint. A command word still wins even then, because Electron
  apps hide their selection from Accessibility until the key is up, and
  someone saying "fix" in Slack meant fix.
- **The date is read on-device by Apple's data detector, not a model.**
  "Thursday", "tomorrow at 3pm", "14 October" become a due date; a time of
  day also sets an alarm. The phrase and its preposition leave the title:
  "call the dentist on Thursday" is *Call the dentist*, due Thursday. What
  the detector cannot read — "in two hours", "next month" — stays in the
  title, and the to-do still lands. Openers are stripped: "remind me to",
  "note to self", "add a task".
- **The polisher cleans it first**, so "um call the the dentist" is what it
  should be; its full stop is not part of a to-do.
- **The list is "Timbre"**, created on first use in the account the user's
  default reminders live in — or any list they pick in Settings. Both, as
  Hugo chose.
- **Read it back:** tap left ⌥ with nothing selected and Timbre reads the
  open to-dos in that list, soonest first, undated last, dates spoken as
  "tomorrow" and "Thursday".
- **Full Reminders access**, asked for on the first capture, because
  reading the list back needs it; Settings shows the state and links to the
  system setting if it was refused.

## Consequences

- The privacy page gains nothing: no request is made by Timbre. The
  Reminders permission is a new entry in the permissions list and in the
  first-run story.
- What is captured is stored by Apple, in Reminders, in the user's iCloud
  if they sync Reminders — which is where they asked for it to be.
- The parser is deterministic and tested; the store is EventKit, which no
  unit test can exercise without a permission grant, so the first real
  capture is its test.
- "In two hours" and "next month" are the known gaps; a to-do with the
  phrase left in its title is the honest failure.

## Alternatives considered

- **A Timbre list synced through iCloud key-value storage:** rejected;
  invisible on the phone without an iOS app, which GDR-0002 rules out.
- **A model to parse the date:** rejected; the detector is deterministic,
  instant and already on the Mac.
- **Write-only access:** rejected; reading the list back is half the point.
- **A fourth key for capture:** rejected; no selection is the signal, and a
  fourth modifier is one too many.
