# 0003 — Text insertion via pasteboard + synthetic ⌘V

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

After polishing, Spoke must place text into whatever field the user was
focused on, in any application. Two mechanisms exist on macOS:

1. **Accessibility API** — set the focused element's `AXValue` directly.
   Clean in principle, but Electron apps, terminals, and many web views
   either don't expose a settable value or mangle the result.
2. **Pasteboard + synthetic ⌘V** — identical to the path a human takes, so
   it works essentially everywhere. Shipping dictation apps in this category
   converged on it.

## Decision

We will insert via the pasteboard with a synthetic ⌘V, saving the user's
pasteboard contents first and restoring them (all items, all representations)
after the paste has been consumed.

Consequences of this choice are load-bearing elsewhere:

- **App Sandbox must stay off** — sandboxed apps cannot post keyboard events
  to other apps. This commits us to direct distribution over the App Store
  (see [GDR-0001](../gdr/0001-local-only-free-no-account.md)).
- **Accessibility permission is required** and must be verified before
  posting the event; without it the paste silently does nothing.
- The restore delay (~150 ms) is a heuristic; too short pastes the old
  clipboard, too long is user-visible. It is a documented constant, not
  magic.

## Consequences

- Insertion works in effectively every app, including the hostile ones.
- The user's clipboard is briefly occupied; a crash in the window between
  set and restore loses their clipboard contents. Accepted risk at this
  stage.
- Transient clipboard managers may record the inserted text; local-only
  managers don't violate the privacy story, but it's worth documenting.

## Alternatives considered

- **AX value insertion with pasteboard fallback:** rejected for now — two
  paths to test and the fallback would carry all the traffic anyway.
  Revisit if the clipboard-occupation window proves annoying.
- **CGEvent keyboard typing (character by character):** rejected — slow,
  breaks with non-ASCII input sources, and looks like a keylogger to
  security software.
