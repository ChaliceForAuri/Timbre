# 0008 — Taught vocabulary does not reach SpeechTranscriber; stay on it anyway

- **Status:** Accepted
- **Date:** 2026-09-13

## Context

The roadmap and GDR-0010 assumed taught words would reach the speech model
through `SFCustomLanguageModelData`, fixing the "spell kid" class of error
where the transcriber lands too far from a term for the polisher to recover
it. That assumption was checked against the macOS 26.5 SDK and measured with
`timbre-eval --audio-dir Fixtures/audio --corpus Fixtures/corpus.json`, which
pairs each fixture with its case's vocabulary and reports how many taught
terms came back verbatim. The fixture for this is `11-hard-vocabulary`: one
sentence, five taught terms, synthesized by `say`.

What the SDK offers:

- `SpeechTranscriber` — Timbre's module — has no custom-language-model hook.
  Its only vocabulary surface is `AnalysisContext.contextualStrings[.general]`
  on the analyzer, set with `setContext(_:)` or at init.
- `DictationTranscriber`, a sibling module, has both: contextual strings and
  `ContentHint.customizedLanguage(modelConfiguration:)`, which takes a model
  prepared from `SFCustomLanguageModelData` by `SFSpeechLanguageModel`.

What was measured, transcribing fixtures 06 and 11 with their six taught terms:

| Engine | Vocabulary route | Recalled | Notes |
|---|---|---|---|
| SpeechTranscriber | none | 0/6 | "timber kit", "superbasin lang views", "Swift UI", "evils" |
| SpeechTranscriber | contextual strings, set before `start` | 0/6 | output byte-identical to unbiased |
| SpeechTranscriber | … on a fresh, unprepared session | 0/6 | identical |
| SpeechTranscriber | … via `init(inputSequence:…analysisContext:)` | 0/6 | identical |
| SpeechTranscriber | … after `start` | 0/6 | identical |
| DictationTranscriber | none | 1/6 | got "SwiftUI" unaided; "Tamber kid", "soup basin Lang fuse", "levels" |
| DictationTranscriber | contextual strings | 2/6 | recovered "Langfuse"; net gain one term |
| DictationTranscriber | custom LM (phrase count 10 per term) + contextual strings | 2/6 | model prepared in 0.57 s; no further gain |

`setContext` never threw on `SpeechTranscriber`. It simply changes nothing.

And the polisher, handed the same five terms in its prompt, five runs on the
`SpeechTranscriber` transcript: "Swift UI" → "SwiftUI" 4/5, "evils" → "evals"
1/5, Supabase and Langfuse 0/5 — and "timber kit" → "TimberKit" 5/5, never
"TimbreKit", while case 06's "timbre kit" is fixed 5/5. One letter of phonetic
distance is one too many for the model; that is the class of error left.

`DictationTranscriber` across all eleven fixtures, both progressive presets:
it drops everything after a spoken "new paragraph" (fixture 04 came back as
"Send it to the team." alone), hears "um" as "am", and ends fewer sentences
with punctuation. It streams more evenly — snapshots every ~200 ms against
`SpeechTranscriber`'s ~1 s bursts — which would suit the overlay. Long and
short presets produced identical transcripts.

The four terms neither engine recovers are phonetic, not orthographic: the
synthesized voice says "timber kit" for TimbreKit, "soup basin" for "Supabase
and", "evils" or "levels" for "evals". No bias corrects a mispronunciation.
`CustomPronunciation` in the custom model is the tool for that, but it wants
phoneme strings and is `DictationTranscriber`-only.

## Decision

We will stay on `SpeechTranscriber`. The `AnalysisContext` hook stays wired
from `DictationController` through `Transcriber.startDictation(consuming:
vocabulary:)`: it is the documented API, it costs nothing, and the harness
reports recall on every run, so an SDK that starts honouring it will show up
as a number rather than a hope. `Transcriber` says in its own comment that
the call is measured ineffective today.

Taught words correct the transcript **in the pipeline**, deterministically,
where they can be tested: the polisher already receives them, and the next
step is a "heard → meant" correction table so that "timber kit" becomes
"TimbreKit" before the model sees it. That is a product decision and gets its
own record.

## Consequences

- The "spell kid" class is not fixed by this record; it is characterised.
  Fixture 11 keeps the measurement honest: its `spoken` line is what the
  fixture says, its `transcript` is what the engine emitted, and its
  vocabulary is what the harness biases with. It declares no polisher
  checks, because none can hold; the recall line is its assertion.
- GDR-0010's line "taught words reach the transcriber via
  `SFCustomLanguageModelData`" is superseded in fact by this record; that
  record is immutable and stays as written. The dictionary is still the
  prerequisite for sync; the order becomes dictionary → correction table →
  command mode → sync.
- `timbre-eval --audio-dir … --corpus …` is the instrument for any future
  attempt at the engine: change the module or the SDK, run it, read the
  recall line.
- Switching to `DictationTranscriber` remains possible later, on evidence
  from real recordings rather than a synthetic voice, and would have to
  answer for the dropped "new paragraph" tail first.

## Alternatives considered

- **Switch to `DictationTranscriber`:** rejected on the numbers above — one
  net term against a lost sentence tail, a mis-heard filler, and weaker
  punctuation.
- **Run both modules in one analyzer:** rejected; double the compute for two
  transcripts that would then need merging.
- **`SFCustomLanguageModelData` through the old `SFSpeechRecognizer`:**
  rejected; it means leaving `SpeechAnalyzer` and its streaming model.
- **Harder prompting of the polisher:** rejected; it cannot recover
  "superbasin lang views" from any instruction (see case 11).
