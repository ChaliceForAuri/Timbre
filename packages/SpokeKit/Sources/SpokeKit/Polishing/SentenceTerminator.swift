/// Guarantees polished text ends with sentence-ending punctuation.
///
/// This started as a prompt rule and the model would not honour it: it
/// punctuated *between* sentences and left the last one open, failing 5 of 5
/// runs on some inputs through two rounds of tuning — once in the
/// instructions and once in the `@Guide` description at the generation site.
///
/// Terminal punctuation is a mechanical transformation with a right answer, so
/// a 3B model was the wrong tool for it. Doing it here is deterministic,
/// instant, and free. See ADR-0005.
nonisolated enum SentenceTerminator {

    /// Closers that may legitimately sit *after* the terminator, as in
    /// `(see the docs.)` — so the character that decides is the last one
    /// before this run, not the last one in the string.
    private static let closers: Set<Character> = [
        "\"", "'", "\u{201D}", "\u{2019}", ")", "]", "}", "\u{00BB}",
    ]

    /// Adds a full stop when, and only when, the text ends in a word.
    ///
    /// The condition is an allowlist — a letter or a digit — rather than a
    /// list of things to skip. Anything unanticipated (an emoji, a trailing
    /// dash, a clause mark, an ellipsis, a symbol) is therefore left alone
    /// instead of collecting a stray full stop. Appending after a comma would
    /// produce ",." and guessing what the speaker meant is how a guardrail
    /// turns into a bug.
    static func terminated(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        guard let deciding = trimmed.reversed().first(where: { !closers.contains($0) }) else {
            return trimmed
        }
        guard deciding.isLetter || deciding.isNumber else { return trimmed }

        return trimmed + "."
    }
}
