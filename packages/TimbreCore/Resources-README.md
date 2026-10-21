# Bundled words

`Sources/TimbreCore/Resources/bundled-words.json` is the data the word of
the day falls back on when nothing in the Library is due (GDR-0027). It is
written by `tools/extract-words.swift` from a Wiktionary extract
(kaikki.org) and the term lists in `Lists/`, and committed. It is a
derivative of Wiktionary and carries Wiktionary's licence, CC BY-SA 4.0
(GDR-0028); see `LICENSE-DATA.md`. An empty array means no bundled words
yet; the app then never shows a bundled word.
