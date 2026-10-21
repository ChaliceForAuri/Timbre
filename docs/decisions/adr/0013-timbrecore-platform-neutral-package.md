# 0013 — TimbreCore: the platform-neutral package, and the rule for what goes where

- **Status:** Accepted
- **Date:** 2026-10-18
- **Builds on:** [ADR-0002](0002-package-plus-shell-monorepo.md) (one
  package until a real boundary demands a second),
  [ADR-0001](0001-swift-6-language-mode.md),
  [ADR-0004](0004-evaluation-harness-seam.md). Decides the split
  [GDR-0023](../gdr/0023-the-library.md) (decision 4) asked for, with
  [GDR-0026](../gdr/0026-apple-watch-the-wrist-key.md) in view.

## Context

ADR-0002 put everything in one package and said a second would exist only
when a real boundary demanded it. GDR-0023 made the iPhone a companion and
GDR-0026 the Watch, and both will run the Library, the daily pick, the drill
checks and the to-do parser. `TimbreKit` cannot be the package they import:
it declares `macOS 26` as its only platform and imports AppKit, the
Accessibility API and `Speech`. Nor should the shared logic be wrapped in
availability checks inside it — SwiftPM platforms are declared per package,
so every shared type would carry the macOS floor.

## Decision

**A second package, `packages/TimbreCore`, holds what three apps share, and
`TimbreKit` depends on it. The split happened as the Library was born, so
nothing moved twice.**

```
packages/TimbreCore/   Library/   the Library: entries, five kinds, events,
                                  merge, the file, the sync interface;
                                  Correction, Acronym and their tables
                       Learning/  Strength (ADR-0014), the daily pick, Spell
                                  it's check, the met detector, bundled
                                  lists, the corpora
                       Text/      SentenceCapitalizer
                       Todos/     Todo, TodoParser, TodoPhrasing
                       Fixtures/  spell.json, picks.json
                       Platforms: macOS 26, iOS 26, watchOS 26.
packages/TimbreKit/    The macOS pipeline, as before, importing TimbreCore.
```

The rule for what goes where:

- **Core imports `Foundation` and `Observation`, and nothing else.** No
  AppKit, UIKit, EventKit, Speech, CloudKit or FoundationModels. What needs
  a framework or the model is a protocol in Core — `LibrarySync` today, the
  model-backed judge when Say it arrives — and an implementation beside the
  framework.
- **Pure logic with a right answer goes to Core**; anything that touches a
  Mac — the microphone, the pasteboard, Accessibility, Reminders, the model
  — stays in Kit. `ReminderStore` stayed; `TodoParser` moved.
- **The same language mode as Kit** (ADR-0001), by copy: Swift 6, default
  MainActor isolation, the approachable-concurrency features. Model types
  are `nonisolated`; the `Library` is `@Observable` on the main actor.
- **A public surface sized for three consumers.** Core exports the Library,
  its entries, events and kinds, `Strength`, `DailyPicker`, `SpellCheck`,
  `MetDetector`, the corpora, the to-do parser and the capitalizer. Kit
  re-exports Core (`@_exported import`) so the app shell still imports one
  module and the Xcode project did not change; `DictationController`
  exposes the `Library` and keeps its three-list pass-throughs for Settings.
- **Storage is one versioned JSON document**, `library.json` in Application
  Support, written whole and atomically, with a schema version and fields
  only ever added. Sync is a `LibrarySync` behind which CloudKit will sit
  (GDR-0023, decision 1); the merge is the Library's own pure rule, not the
  file's. SwiftData is not used: its CloudKit mirroring cannot express a
  union of histories, and a file is inspectable, exportable and testable.
- **Tests beside it, fixtures beside them.**
  `swift test --package-path packages/TimbreCore` is the fast loop for
  anything in Core; `timbre-eval --spell` and `--picks` run the same corpora
  from the harness (ADR-0004). The harness stays in Kit, where the model is.

## Consequences

- Two packages, two test runs, one more `Package.swift` kept aligned by
  hand.
- `VocabularyStore` is gone. The three `UserDefaults` lists are imported
  once into the Library on first launch, in order, and left in place for a
  downgrade; the migration is tested against the old format.
- The Mac app links `TimbreKit` alone; the companion's project will link
  `TimbreCore` alone. Its structure is a record when it exists.
- `timbre-eval` imports Core directly for the corpora; the dictation and
  command corpora decode `Correction` and `Acronym` from Core unchanged.
- Today's word is marked *met* from the polished text (GDR-0027) in
  `DictationController`, after every dictation and spoken to-do. Command
  mode's selection is someone's typing, not the user's voice, so it does not
  count.

## Alternatives considered

- **More targets in the one package:** rejected; the platform floor is per
  package.
- **Copy the Library into the iOS app:** rejected; two stores, diverging by
  the second week.
- **The pipeline in Core behind `#if os(macOS)`:** rejected; conditional
  compilation across a pipeline is a worse boundary than a package.
- **SwiftData with CloudKit mirroring:** rejected for the merge rule;
  revisit only if a union merge becomes expressible.
