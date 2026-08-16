# 0002 — Monorepo: SpokeKit package + thin Xcode shell, no generator tooling

- **Status:** Accepted
- **Date:** 2026-08-15

## Context

The repository will hold everything Spoke: the macOS app, the website, the
decision records, and the learning material. The app logic needs tests, but
an Xcode app target is a poor test host — `swift test` on a package runs in
seconds with no app launch, no signing, no simulator.

Historically, monorepos with Xcode projects reached for generator tools
(XcodeGen, Tuist) to escape `project.pbxproj` merge conflicts. Xcode 16+
file-system-synchronized folders removed the cause: source files are no
longer enumerated in the project file at all.

## Decision

We will structure the repository as:

```
apps/Spoke/        Xcode project: @main, scenes, xcconfig build settings
packages/SpokeKit/ Swift package: the entire pipeline, all testable logic
docs/              decisions, learning material
web/               website (placeholder until the app ships)
```

- **One package**, `SpokeKit`, with internal folder structure. We split into
  more packages only when a real boundary demands it (e.g. a future CLI or
  command-mode target), not preemptively.
- The app target contains **only** scene declarations and views that glue
  SpokeKit to SwiftUI scenes. If a file doesn't mention `App`, `Scene`, or a
  scene-level view, it belongs in the package.
- **No project generators, no linters beyond `swift-format`** (which ships in
  the toolchain). Build settings live in `.xcconfig` files under version
  control; the `.pbxproj` stays minimal and rarely changes.
- CI is path-filtered: `web/` changes don't trigger Xcode builds and vice
  versa.

## Consequences

- Logic is testable by construction; `public` marks the deliberate API
  surface of the pipeline and everything else stays internal.
- Zero third-party tooling to install, version, or explain — `git clone`,
  open, build.
- Two build systems (SwiftPM + xcodebuild) exist in one repo; CI runs both.
- Contributors touch the `.pbxproj` so rarely that conflicts stop being a
  concern.

## Alternatives considered

- **Everything in the app target (planning-phase layout):** rejected — no
  test story, no API boundary, pbxproj owns the file list.
- **Multiple micro-packages (SpokeAudio, SpokeSpeech, …):** rejected —
  boundaries invented before they're discovered become walls in the wrong
  places.
- **XcodeGen / Tuist:** rejected — solves a problem Xcode 16 already solved,
  at the cost of a third-party dependency in violation of the no-dependencies
  rule.
- **Separate repos for app and website:** rejected — releases, download
  links, and decision records must version together; the coordination cost
  of split repos buys nothing at this scale.
