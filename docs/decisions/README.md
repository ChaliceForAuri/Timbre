# Decision records

> Records written before 2026-08-21 call the product *Spoke*; it was renamed
> to *Timbre* in [GDR-0009](gdr/0009-renamed-to-timbre.md). They are immutable
> and were left as written.

Two kinds of records live here. The boundary rule:

> **If the decision constrains a file, it's an ADR. If it constrains the
> product, it's a GDR.** When in doubt, it's a GDR.

- **ADRs** (`adr/`) — Architecture Decision Records. Technical choices:
  language mode, module boundaries, mechanisms, frameworks.
- **GDRs** (`gdr/`) — General Decision Records. Product and project choices:
  scope, positioning, pricing, distribution, non-goals.

## Process

1. Copy the `0000-template.md` in the relevant directory.
2. Number sequentially, kebab-case title: `0004-short-slug.md`.
3. Status is one of `Proposed`, `Accepted`, `Superseded by [NNNN](...)`.
4. Records are **immutable once accepted**. To change course, write a new
   record that supersedes the old one and link both ways. The old record's
   reasoning is the valuable part — never delete it.

## Index

### ADRs

| # | Title | Status |
|---|---|---|
| [0001](adr/0001-swift-6-language-mode.md) | Swift 6 language mode with default MainActor isolation | Accepted |
| [0002](adr/0002-package-plus-shell-monorepo.md) | Monorepo: TimbreKit package + thin Xcode shell, no generator tooling | Accepted |
| [0003](adr/0003-insertion-via-pasteboard-paste.md) | Text insertion via pasteboard + synthetic ⌘V | Accepted |
| [0004](adr/0004-evaluation-harness-seam.md) | A second public seam for the evaluation harness | Accepted |
| [0005](adr/0005-deterministic-sentence-termination.md) | Terminal punctuation is deterministic, not the model's job | Accepted |
| [0006](adr/0006-speech-sessions-are-single-use.md) | A speech session is single-use; rebuild it per dictation | Accepted |
| [0007](adr/0007-hotkey-path-avoids-concurrency-runtime.md) | The hotkey event path stays out of the concurrency runtime | Accepted |

### GDRs

| # | Title | Status |
|---|---|---|
| [0001](gdr/0001-local-only-free-no-account.md) | Local-only, free, no account | Accepted |
| [0002](gdr/0002-english-first-macos-only.md) | English-first, macOS-only | Accepted |
| [0003](gdr/0003-structural-spoken-commands-only.md) | Timbren commands: structure only, never punctuation | Accepted |
| [0004](gdr/0004-opt-in-local-dictation-capture.md) | Dictation capture is opt-in, local, and deletable | Accepted |
| [0005](gdr/0005-licensing-preserves-optionality.md) | Licensing starts closed to preserve optionality | Accepted |
| [0006](gdr/0006-app-never-phones-home.md) | The app never phones home; privacy is never a paid tier | Accepted |
| [0007](gdr/0007-backstage-web-lab.md) | Backstage: a web lab fed by dev-side artifacts | Accepted |
| [0008](gdr/0008-voice-in-and-out.md) | Timbre is a voice interface, not a dictation app | Accepted |
| [0009](gdr/0009-renamed-to-timbre.md) | The product is called Timbre (was Timbre) | Accepted |
