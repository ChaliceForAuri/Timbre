import Foundation

/// Collapses an accidentally repeated function word: "the the" → "the".
///
/// Measured, the model leaves these alone three runs in five. It is a
/// mechanical error with a right answer, so it is fixed here rather than
/// asked for (ADR-0005). Only words that are never legitimately doubled are
/// touched — "had had", "that that" and "very very" are all real English.
nonisolated enum DoubledWords {

    private static let collapsible = [
        "the", "a", "an", "of", "to", "and", "in", "on", "for", "with", "at", "by", "from", "or",
    ]

    static func collapsed(_ text: String) -> String {
        var result = text
        // One pattern per word rather than a backreference: under
        // case-insensitive matching a backreference still compares exactly,
        // so "The the" slipped through.
        for word in collapsible {
            guard let pattern = try? Regex("\\b(\(word))(?:\\s+\(word)\\b)+").ignoresCase() else { continue }
            result = result.replacing(pattern) { match in
                // Keep the first occurrence as written, capital and all.
                match.output[1].substring.map(String.init) ?? word
            }
        }
        return result
    }
}
