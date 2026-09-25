import Foundation

/// Keeps the model's hands off the parts of a text that have exactly one
/// right spelling: Slack mentions, URLs, emails, dates, times, numbers with
/// units, code spans, and abbreviations like "e.g." (GDR-0015).
///
/// Each literal is swapped for a placeholder before the model runs and put
/// back after. The model is told the placeholders are untouchable; whether
/// it listens is what the corpus measures. Explain never masks — the model
/// has to read the literal to explain it.
nonisolated struct LiteralGuard {

    /// A masked text and what was taken out of it.
    struct Masked: Equatable {
        let text: String
        let literals: [String]
    }

    /// The placeholder for literal `index`. Measured across fix, shorten and
    /// plain: brackets and symbols — ⟦1⟧, [[1]], {{1}}, <1>, §1 — are stripped
    /// by the model in at least one verb; a word-shaped token survives all of
    /// them. Restored case-insensitively, since plain text may lowercase it.
    static func placeholder(_ index: Int) -> String { "LIT\(index)" }

    /// Literal patterns, in the order they are tried; earlier wins on
    /// overlap. Group 1 is the literal — Swift's regex engine has no
    /// lookbehind, so context before a literal is matched and then dropped.
    /// Strings, compiled per call: a Regex is not Sendable, and masking runs
    /// once per command.
    private static let patterns: [String] = [
        // Slack: <@U01AB2CD3EF>, <#C123|name>, @here, @channel, @Eric.Greene, #eng-releases
        #"(<[@#!][^>]+>)"#,
        #"(@(?:here|channel|everyone))\b"#,
        #"(?:^|[^\w.])(@[\w.\-]+)\b"#,
        #"(?:^|[^\w&])(#[A-Za-z][\w\-]*)\b"#,
        // Code spans and paths
        #"(`[^`\n]+`)"#,
        #"(?:^|[^\w/])((?:~|\.{1,2})?/[\w.\-]+(?:/[\w.\-]+)+)\b"#,
        // Web
        #"(https?://[^\s<>()"']+)"#,
        #"\b(www\.[^\s<>()"']+)"#,
        #"\b([\w.+\-]+@[\w\-]+(?:\.[\w\-]+)+)\b"#,
        // Dates and times
        #"\b(\d{1,4}[/.\-]\d{1,2}[/.\-]\d{1,4})\b"#,
        #"\b(\d{1,2}:\d{2}(?::\d{2})?(?:\s?[apAP]\.?[mM]\.?)?)(?![\w])"#,
        #"\b(\d{1,2}\s?[apAP]\.?[mM]\.?)(?![\w])"#,
        // Numbers with units — single-letter units only without a space, so
        // "3 in the morning" is not a measurement. Percentages, temperatures.
        #"\b(\d+(?:[.,]\d+)?(?:\s?(?:ms|sec|secs|min|mins|hr|hrs|kg|mg|lbs?|oz|km|cm|mm|mi|ft|kb|mb|gb|tb|KB|MB|GB|TB|px|pt|fps|Hz|kHz|MHz|GHz|%|°[CF]?)|[smhd]))(?![\w])"#,
        // Versions
        #"\b(v?\d+\.\d+(?:\.\d+)+)\b"#,
        // Abbreviations the model likes to expand or delete
        #"\b((?:e\.g\.|i\.e\.|etc\.|vs\.|approx\.|cf\.))(?![\w])"#,
    ]

    /// Replaces every literal with a placeholder.
    static func mask(_ text: String) -> Masked {
        var ranges: [Range<String.Index>] = []
        for pattern in patterns {
            guard let regex = try? Regex(pattern) else { continue }
            for match in text.matches(of: regex) {
                let range = match.output.count > 1 ? (match.output[1].range ?? match.range) : match.range
                guard !range.isEmpty, !ranges.contains(where: { $0.overlaps(range) }) else { continue }
                ranges.append(range)
            }
        }
        ranges.sort { $0.lowerBound < $1.lowerBound }

        var literals: [String] = []
        var masked = ""
        var cursor = text.startIndex
        for range in ranges {
            masked += text[cursor..<range.lowerBound]
            literals.append(String(text[range]))
            masked += placeholder(literals.count)
            cursor = range.upperBound
        }
        masked += text[cursor...]
        return Masked(text: masked, literals: literals)
    }

    /// Puts the literals back. Returns nil when the model damaged a
    /// placeholder or, with `requireAll`, left one out — the caller then
    /// treats the result as unusable rather than pasting a hole.
    static func restore(_ text: String, from masked: Masked, requireAll: Bool) -> String? {
        var seen: Set<Int> = []
        var result = text
        for match in text.matches(of: /(?i)LIT(\d+)/) {
            guard let index = Int(match.output.1), index >= 1, index <= masked.literals.count else {
                return nil
            }
            seen.insert(index)
        }
        if requireAll, seen.count != masked.literals.count { return nil }
        for (offset, literal) in masked.literals.enumerated() {
            result = result.replacingOccurrences(
                of: placeholder(offset + 1), with: literal, options: .caseInsensitive)
        }
        return result
    }

    /// The sentence the model is given about the placeholders, when there are any.
    static func instruction(for masked: Masked) -> String? {
        guard !masked.literals.isEmpty else { return nil }
        return
            "Tokens like \(placeholder(1)) stand for text that must not change — names, links, dates, "
            + "times, units. Keep every token exactly as it is, in its place."
    }
}
