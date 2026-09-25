import Foundation

/// What command mode can do to a selection (GDR-0012).
nonisolated public enum VoiceCommand: String, Sendable, CaseIterable, Codable {
    /// Correct spelling, grammar and punctuation; change nothing else.
    case fix
    /// Say what the selection means. Shown, never pasted.
    case explain
    /// Say the same thing in fewer words.
    case shorten
    /// Strip the filler and the machine phrasing; keep what it says (GDR-0015).
    case plain

    /// Shown in the pill while the key is held and nothing has been said yet.
    static let hint = "fix · explain · shorten · plain"

    /// Shown in the pill while the command runs.
    var progressLabel: String {
        switch self {
        case .fix: "Fixing…"
        case .explain: "Explaining…"
        case .shorten: "Shortening…"
        case .plain: "Making it plain…"
        }
    }

    /// Whether the command rewrites the selection (as opposed to showing something).
    var rewritesText: Bool { self != .explain }

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
        TextMatch.normalized(transcript).isEmpty ? .fix : recognized(in: transcript)
    }

    /// The command in a transcript that is still arriving, or nil — never
    /// `.fix` for silence, because silence mid-hold only means "not yet".
    /// Command mode acts the moment this returns a command (GDR-0014), so it
    /// is deliberately the same whole-word lookup as `parse`: a partial result
    /// can fire a command only by containing one of its words.
    static func recognized(in transcript: String) -> VoiceCommand? {
        for word in TextMatch.normalized(transcript).split(separator: " ") {
            if let command = vocabulary[String(word)] { return command }
        }
        return nil
    }

    /// `recognized(in:)`, plus one allowance for a word still being spoken.
    ///
    /// Measured: the first live result arrives about 1.1 s into a spoken
    /// command, often as a *partial* word — "Expl", "Acr" — and the whole
    /// word only in the next burst, near 2 s. So the last word of a live
    /// result may fire a command on a clear prefix of three letters or more,
    /// but only when every word it could be finishing means **explain**.
    /// Explain never touches the user's text, so the worst misfire is a card
    /// nobody asked for. Fix and shorten rewrite text and wait for the whole
    /// word; they arrive whole in the first burst anyway ("Fix", "Short").
    static func recognizedWhileSpeaking(in transcript: String) -> VoiceCommand? {
        if let command = recognized(in: transcript) { return command }
        guard let last = TextMatch.normalized(transcript).split(separator: " ").last,
            last.count >= minimumPrefix
        else { return nil }
        let completions = vocabulary.filter { $0.key.hasPrefix(last) }.map(\.value)
        return !completions.isEmpty && completions.allSatisfy { $0 == .explain } ? .explain : nil
    }

    private static let minimumPrefix = 3

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
            .plain: [
                "plain", "plainly", "plainer", "simple", "simpler", "simplify", "simplified", "deslop",
                "slop",
                "human", "natural", "normal", "jargon", "honest", "unslop",
            ],
        ]
        for (command, words) in aliases {
            for word in words { table[word] = command }
        }
        return table
    }()
}
