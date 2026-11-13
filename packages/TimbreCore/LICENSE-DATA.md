# Licence for the bundled word data

`Sources/TimbreCore/Resources/bundled-words.json` — the definitions, parts
of speech, pronunciations, origins and word parts shown on Timbre's word
cards and labelled *Wiktionary* — is a curated extract of the English
Wiktionary, produced by `tools/extract-words.swift` from the machine-
readable dump at https://kaikki.org/dictionary/ (made with wiktextract).

Wiktionary's text is dual-licensed under the Creative Commons
Attribution-ShareAlike 4.0 International licence (CC BY-SA 4.0) and the GNU
Free Documentation License. Timbre uses it under CC BY-SA 4.0:

- **Attribution.** The contributors of the English Wiktionary. Each entry's
  page is at https://en.wiktionary.org/wiki/<term>. The app shows *Source:
  Wiktionary* on every card that shows this data.
- **ShareAlike.** This file and the script that produces it are available
  under the same licence, CC BY-SA 4.0:
  https://creativecommons.org/licenses/by-sa/4.0/

This licence covers the data file and the extraction script only. Timbre's
own source code is licensed separately (see the repository's LICENSE and
GDR-0005); the data is a file the app reads, not a part of the program.

The word lists in `Lists/` — which terms were chosen for each list — are
Timbre's own curation and are also offered under CC BY-SA 4.0.
