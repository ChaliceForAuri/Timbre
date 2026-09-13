import Foundation

/// Applies taught corrections to a transcript: whole phrases, case ignored,
/// replaced verbatim. Deterministic, so it runs before the model — a
/// mechanical transformation with a right answer is not delegated to a 3B
/// model (ADR-0005, GDR-0011).
///
/// The polisher, handed "TimbreKit" as vocabulary, fixes "timbre kit" five
/// times out of five and "timber kit" never. One letter of phonetic distance
/// is one too many for it; it is nothing to a lookup.
nonisolated enum CorrectionTable {

    static func applied(_ corrections: [Correction], to text: String) -> String {
        guard !corrections.isEmpty else { return text }
        var result = text
        // Longest phrase first, so a taught "lang views" wins over a taught "views".
        for correction in corrections.sorted(by: { $0.heard.count > $1.heard.count }) {
            guard let pattern = pattern(matching: correction.heard) else { continue }
            result = result.replacing(pattern, with: correction.meant)
        }
        return result
    }

    /// The phrase as whole words with any run of whitespace between them, case
    /// ignored. A word boundary is demanded only next to a letter or digit, so
    /// a phrase ending in a symbol ("c++") still matches.
    static func pattern(matching heard: String) -> Regex<AnyRegexOutput>? {
        let words = heard.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first, let last = words.last?.last else { return nil }

        let body = words.map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "\\s+")
        let lead = first.isLetter || first.isNumber ? "\\b" : ""
        let trail = last.isLetter || last.isNumber ? "\\b" : ""
        return try? Regex(lead + body + trail).ignoresCase()
    }
}
