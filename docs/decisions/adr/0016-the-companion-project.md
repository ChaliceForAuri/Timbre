# 0016 — The companion: one project, four targets, a shared container, and widgets that read a snapshot

- **Status:** Accepted
- **Date:** 2026-10-18
- **Builds on:** [ADR-0002](0002-package-plus-shell-monorepo.md) (a thin
  Xcode shell, settings in xcconfig, no generators),
  [ADR-0013](0013-timbrecore-platform-neutral-package.md) and
  [ADR-0015](0015-a-package-per-framework.md) (what the targets link);
  [GDR-0023](../gdr/0023-the-library.md), [GDR-0026](../gdr/0026-apple-watch-the-wrist-key.md),
  [GDR-0029](../gdr/0029-the-wrist-captures-the-iphone-files.md).

## Context

ADR-0013 left the companion's project structure for the day it existed.
It exists. The questions it had to answer: one project or two; how the
widgets and the complication learn today's word without opening the
Library; where the Watch's queue lives; and how to write an Xcode project
with four targets, two embeds and five packages by hand, because ADR-0002
rules out generators and the Mac project was written the same way.

## Decision

**One project, `apps/Companion/Companion.xcodeproj`, with four targets and
every setting in xcconfig.**

```
apps/Companion/
  Companion.xcodeproj     hand-written; synchronized folders; shared schemes
  Config/                 Shared, Debug, Release; one xcconfig, one
                          entitlements and (where keys cannot say it) one
                          Info.plist per target
  iOS/Sources/            Timbre (iPhone): the tabs, the coordinator, the
                          App Intents
  Watch/Sources/          Timbre Watch App: one scrolling screen, the
                          Action Button's intent
  iOSWidgets/Sources/     TimbreWidgets: the word on the Home and Lock
                          Screens; the Control that opens the to-do key
  WatchWidgets/Sources/   Timbre Watch Widgets: the complication
```

- **Targets link exactly the packages their platform allows** (ADR-0015).
  The iPhone: Core, Speech, Model, Reminders, Relay. The Watch: Core,
  Reminders, Relay. Each widget extension: Core only.
- **The iPhone app embeds the Watch app and its extension; the Watch app
  embeds its own.** Xcode's single-target watch app, `SKIP_INSTALL` on
  everything embedded, bundle identifiers `dev.hugopretorius.Timbre`,
  `.watchkitapp`, `.widgets` and `.watchkitapp.widgets`. The iPhone shares
  the Mac's identifier so the two can one day be one purchase; they share
  the CloudKit container regardless.
- **The app and its extensions share one container**, the app group
  `group.dev.hugopretorius.Timbre`, and `SharedContainer` in Core is the
  one place that knows the path — falling back to Application Support when
  a build has no entitlement, so a simulator build still runs.
- **Widgets read a snapshot, never the Library.** The app writes
  `today.json` — the term, one line, why, met, and which day — whenever its
  card rebuilds, and reloads the timelines. A widget shows nothing once the
  day has moved on. The Watch's complication works the same way from the
  Watch's own snapshot.
- **The Watch's queue of unfiled to-dos** is a file in its container,
  `pending-todos.json`, owned by `TimbreRelay` (GDR-0029).
- **One coordinator per app** (`CompanionModel`, `WatchModel`), a shared
  instance, so an App Intent run by Siri and the screen the user is
  looking at see one Library.
- **A URL scheme, `timbre://today|todo|practice`**, is how a widget and the
  Lock Screen control open the app on a screen. It is the one key that
  needs an Info.plist file; everything else is `INFOPLIST_KEY_*`.
- **The Mac's conventions hold**: Swift 6, default MainActor isolation,
  warnings as errors, `swift-format lint --strict`, views that hold no
  logic a test could want.

## Consequences

- `xcodebuild -scheme Timbre -destination 'generic/platform=iOS Simulator'`
  builds all four targets; CI runs it. The Watch is compile-verified on
  this machine and run on hardware or a watchOS runtime.
- The project file is edited by hand and rarely: a new target is a
  deliberate act with its IDs chosen, as the Mac's was.
- A snapshot is a copy: a widget can be a minute behind the app, never
  ahead, and never wrong about the day.
- Two more entitlements to carry through signing: the app group on all
  four targets, and later the iCloud container on the two apps.

## Alternatives considered

- **Two projects, one per platform:** rejected; the Watch app is embedded
  in the iPhone app and shares its identity.
- **Widgets opening the Library file:** rejected; two processes writing one
  JSON document, and a widget that computes a pick is a widget that can
  disagree with the app.
- **A workspace with the packages dragged in:** rejected; local package
  references in the project resolve the graph, as the Mac's project proved.
