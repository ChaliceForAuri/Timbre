# 0004 — Dictation capture is opt-in, local, and deletable

- **Status:** Accepted
- **Date:** 2026-08-18

## Context

Tuning the polisher needs real dictation: hesitation, restarts, and the
transcriber's own mistakes. None of that can be written by hand, and none of it
survives synthesis — `say` speaks fillers but not the timing or self-correction
that makes real speech hard to clean.

The only source of real samples is the user's own dictation. Recording it means
writing what someone said to disk, in an app whose entire promise is that
nothing leaves the machine ([GDR-0001](0001-local-only-free-no-account.md)).

Local is not the same as invisible. A dictation log is a transcript of
everything the user has said into every app — plausibly including things typed
into a password field by mistake, a private message, or a medical note. That it
never leaves the Mac does not make it something to create without asking.

## Decision

Spoke may record dictations, subject to all of:

- **Off by default.** The setting starts off and only the user turns it on.
- **Plainly described.** The settings copy says what is written and where, and
  says explicitly that nothing is uploaded.
- **Findable.** "Show in Finder" reveals the file. It lives at
  `~/Library/Application Support/Spoke/dictations.jsonl`, not somewhere opaque.
- **Deletable.** "Delete All" removes it, from the same screen that turns it on.
- **Never uploaded.** No exception, no telemetry, no crash-report attachment.

Records are JSON Lines: appending cannot corrupt what is already written, which
matters for a menu bar app that may be force-quit mid-dictation.

## Consequences

- Real fixtures become possible, which is the only way roadmap item 1 stops
  being guesswork.
- Capture happens *after* the paste, so a fixture write can never sit between
  the user releasing the key and their text appearing.
- Write failures are logged and swallowed. Losing a tuning fixture must never
  cost the user their dictation.
- The corpus importer deliberately leaves `forbidden` and `required` empty.
  Only the person who spoke knows which words had to survive; a machine
  guessing would produce a corpus that measures nothing.
- Audio is **not** captured, only text. Recording audio would raise the privacy
  stakes considerably and is not needed for polisher tuning. If transcription
  quality later needs work — and the "SpokeKit" → "spell kid" finding suggests
  it might — that is a separate decision, not an extension of this one.

## Alternatives considered

- **Capture silently, since it never leaves the Mac:** rejected. The privacy
  story is the product; quietly keeping a transcript of everything the user
  says would betray it whether or not anyone found out.
- **Prompt on first dictation:** rejected as a dark pattern in miniature — a
  consent dialog at the moment someone wants their text is a dialog they will
  dismiss without reading.
- **Capture audio too:** deferred, as above.
