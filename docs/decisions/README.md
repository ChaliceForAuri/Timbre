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
| [0008](adr/0008-taught-vocabulary-and-the-transcriber.md) | Taught vocabulary does not reach SpeechTranscriber; stay on it anyway | Accepted |
| [0009](adr/0009-command-mode-decodes-greedily.md) | Command mode decodes greedily; only fix uses guided generation | Accepted |
| [0010](adr/0010-self-update-without-sparkle.md) | Self-update: verify by code requirement, swap in place, relaunch; no Sparkle | Accepted |
| [0011](adr/0011-polisher-decodes-greedily-capitalizes-deterministically.md) | The polisher decodes greedily; sentence capitals are deterministic | Accepted |
| [0012](adr/0012-silent-bluetooth-input-falls-back.md) | A silent Bluetooth input falls back to the built-in microphone | Accepted |
| [0013](adr/0013-timbrecore-platform-neutral-package.md) | TimbreCore: the platform-neutral package, and the rule for what goes where | Accepted |
| [0014](adr/0014-strength-from-events-fsrs.md) | Strength is retrievability, derived from an entry's events with FSRS-4.5 | Accepted |

### GDRs

| # | Title | Status |
|---|---|---|
| [0001](gdr/0001-local-only-free-no-account.md) | Local-only, free, no account | Accepted · no-sync clause amended by 0010 |
| [0002](gdr/0002-english-first-macos-only.md) | English-first, macOS-only | Accepted · "no iOS app" superseded by 0023 and 0026; dictation stays macOS-only |
| [0003](gdr/0003-structural-spoken-commands-only.md) | Timbren commands: structure only, never punctuation | Accepted |
| [0004](gdr/0004-opt-in-local-dictation-capture.md) | Dictation capture is opt-in, local, and deletable | Accepted |
| [0005](gdr/0005-licensing-preserves-optionality.md) | Licensing starts closed to preserve optionality | Accepted |
| [0006](gdr/0006-app-never-phones-home.md) | The app never phones home; privacy is never a paid tier | Accepted |
| [0007](gdr/0007-backstage-web-lab.md) | Backstage: a web lab fed by dev-side artifacts | Accepted |
| [0008](gdr/0008-voice-in-and-out.md) | Timbre is a voice interface, not a dictation app | Accepted |
| [0009](gdr/0009-renamed-to-timbre.md) | The product is called Timbre (was Timbre) | Accepted |
| [0010](gdr/0010-optional-icloud-sync-of-personal-dictionary.md) | Optional iCloud sync of the personal dictionary (amends 0001's no-sync clause) | Accepted |
| [0011](gdr/0011-taught-corrections-before-the-model.md) | Taught corrections: what Timbre heard becomes what you meant, before the model | Accepted |
| [0012](gdr/0012-command-mode.md) | Command mode: hold right ⌘ on a selection to fix, explain or shorten it | Accepted |
| [0013](gdr/0013-update-check-off-by-default.md) | An update check, off by default, is the only network request Timbre can ever make (amends 0006) | Accepted |
| [0014](gdr/0014-commands-act-on-the-word.md) | Command mode acts on the word, not on the release (amends 0012) | Accepted |
| [0015](gdr/0015-command-mode-plain-verb-literals-fallback.md) | Command mode: a "plain" verb, guarded literals, and a spelling fallback | Accepted |
| [0016](gdr/0016-todos-by-voice-into-reminders.md) | To-dos by voice, into Apple's Reminders | Accepted |
| [0017](gdr/0017-retro-identity-one-colour-per-gesture.md) | A retro identity: keycap grey, and one colour per gesture | Accepted |
| [0018](gdr/0018-words-appear-as-you-speak.md) | Words appear as you speak; the cleanup replaces them on release | Accepted |
| [0019](gdr/0019-outfit-and-a-simpler-drawing.md) | Outfit, served by the site; the keyboard goes; keys are flat (amends 0017) | Accepted |
| [0020](gdr/0020-nunito.md) | Nunito: the rounded face (amends 0019) | Accepted |
| [0021](gdr/0021-the-wordmark.md) | The wordmark: bars beside "timbre", stroke 3; an underlined secondary (amends 0019, 0017) | Accepted |
| [0022](gdr/0022-nunito-sans-for-text.md) | Nunito Sans for text; Nunito keeps the headlines (amends 0020) | Accepted |
| [0023](gdr/0023-the-library.md) | The Library: one store, five kinds, synced by iCloud, practised by voice | Accepted |
| [0024](gdr/0024-the-menu-bar-mark.md) | The menu bar shows the bare bars, and the bars carry the state (amends 0021, 0017) | Accepted |
| [0025](gdr/0025-said-aloud.md) | The lockup says how it is said: /tam·br/ beside the word (amends 0021) | Accepted |
| [0026](gdr/0026-apple-watch-the-wrist-key.md) | Apple Watch: the to-do key on the wrist, the Library at a glance, and no model needed there (extends 0023) | Accepted · implementation pending |
| [0027](gdr/0027-word-of-the-day-the-bar.md) | The word of the day: the bar is Vocabulary.com and the widget apps, and the word is yours first | Accepted · implementation pending |
| [0028](gdr/0028-bundled-word-content-from-wiktionary.md) | Bundled word content comes from a Wiktionary extract, under CC BY-SA; the model writes only examples | Accepted · implementation pending |
