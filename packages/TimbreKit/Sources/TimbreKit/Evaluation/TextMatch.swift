/// Punctuation- and case-insensitive phrase matching with word-boundary
/// semantics.
///
/// An evaluation harness can't assert exact model output: the model is free to
/// punctuate and capitalize as it sees fit, and it varies between runs. What it
/// *can* assert are properties — this filler is gone, that proper noun
/// survived. Both need matching that ignores everything the model is allowed
/// to change.
///
/// Normalizing to lowercase words joined by single spaces, then matching
/// space-delimited, buys word boundaries for free: "um" matches "so um yeah"
/// but not "number".
nonisolated public enum TextMatch {

    /// Lowercased, every non-alphanumeric replaced by a space, runs of
    /// whitespace collapsed. `"Don't — ship it, Friday."` becomes
    /// `"don t ship it friday"`.
    ///
    /// Splitting contractions is harmless because both sides of a comparison
    /// go through here, so "don't" still matches "dont".
    public static func normalized(_ text: String) -> String {
        let letters: [Character] = text.lowercased().map { character in
            (character.isLetter || character.isNumber) ? character : " "
        }
        return String(letters)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// Whether `phrase` appears in `text` as whole words, ignoring case and
    /// punctuation. A phrase with no alphanumerics never matches.
    public static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let needle = normalized(phrase)
        guard !needle.isEmpty else { return false }
        return " \(normalized(text)) ".contains(" \(needle) ")
    }
}
