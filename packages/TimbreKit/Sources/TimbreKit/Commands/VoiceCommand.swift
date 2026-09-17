import Foundation

/// What command mode can do to a selection (GDR-0012).
nonisolated public enum VoiceCommand: String, Sendable, CaseIterable, Codable {
    /// Correct spelling, grammar and punctuation; change nothing else.
    case fix
    /// Say what the selection means. Shown, never pasted.
    case explain
    /// Say the same thing in fewer words.
    case shorten

    /// Shown in the pill while the key is held and nothing has been said yet.
    static let hint = "fix · explain · shorten"

    /// Shown in the pill while the command runs.
    var progressLabel: String {
        switch self {
        case .fix: "Fixing…"
        case .explain: "Explaining…"
        case .shorten: "Shortening…"
        }
    }

    /// Reads a command out of what the transcriber heard.
    ///
    /// - Silence is `fix`: releasing the key without speaking is the default.
    /// - Otherwise the first recognised word wins, so "please explain this"
    ///   and "make it shorter" both work.
    /// - Anything else is nil, and the caller must then do nothing. Two of
    ///   the three commands rewrite the user's text; guessing is not on
    ///   offer. Measured with synthetic voices, a bare "shorten" came back as
    ///   "Jordan" once in two — the phrase forms were solid — which is why
    ///   the alias lists are generous and an unknown word is reported back
    ///   rather than rounded to the nearest command.
    static func parse(_ transcript: String) -> VoiceCommand? {
        let words = TextMatch.normalized(transcript).split(separator: " ")
        guard !words.isEmpty else { return .fix }
        for word in words {
            if let command = vocabulary[String(word)] { return command }
        }
        return nil
    }

    private static let vocabulary: [String: VoiceCommand] = {
        var table: [String: VoiceCommand] = [:]
        let aliases: [VoiceCommand: [String]] = [
            .fix: [
                "fix", "fixed", "fixes", "correct", "correction", "spelling", "spellcheck", "grammar", "typo",
                "typos",
            ],
            .explain: [
                "explain", "explains", "explanation", "acronym", "define", "definition", "meaning", "mean",
                "means", "what",
            ],
            .shorten: [
                "shorten", "shortened", "shorter", "short", "trim", "tighten", "condense", "concise", "brief",
                "briefer",
            ],
        ]
        for (command, words) in aliases {
            for word in words { table[word] = command }
        }
        return table
    }()
}
