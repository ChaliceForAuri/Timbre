import Foundation

/// One snippet (GDR-0032): a short name the user says, and the exact text
/// it stands for. "my email" → the address. The name is what the
/// transcriber can hear reliably; the text is what it cannot — an address,
/// a command, a signature — and is never spoken, so never mis-heard.
nonisolated public struct Snippet: Codable, Sendable, Hashable, Identifiable {

    /// What the user says.
    public let say: String

    /// What is written, verbatim: its case, its symbols and its line breaks.
    public let text: String

    public var id: String { LibraryEntry.normalized(say) }

    /// Nil when either side is empty.
    public init?(say: String, text: String) {
        let say = say.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !say.isEmpty, !text.isEmpty else { return nil }
        self.say = say
        self.text = text
    }
}

/// Finds snippet names in a transcript and keeps their text out of
/// everything that would change it (GDR-0032). Deterministic: a lookup,
/// like the correction table, and for the same reason (GDR-0011).
///
/// Two cases. An utterance that is only a snippet's name *is* the snippet:
/// its text, with no capital and no full stop added. A name inside a
/// sentence is swapped for a placeholder before the model runs and the
/// text is put back after the capital and the full stop are decided, so
/// neither the model nor the sentence rules ever see it.
nonisolated public enum SnippetTable {

    /// A transcript with its snippets taken out.
    public struct Guarded: Equatable, Sendable {
        public let text: String
        /// The snippet texts, in placeholder order: `texts[0]` is `SNIP1`.
        public let texts: [String]
    }

    /// The placeholder for snippet `index`, from 1. Word-shaped, because
    /// the model strips brackets and symbols (measured for GDR-0015).
    public static func placeholder(_ index: Int) -> String { "SNIP\(index)" }

    /// The snippet's text when the utterance is its name and nothing else.
    /// The transcriber capitalises and punctuates what it hears, so case,
    /// spacing and punctuation around the name are ignored.
    public static func whole(_ snippets: [Snippet], utterance: String) -> String? {
        let said = bare(utterance)
        guard !said.isEmpty else { return nil }
        return snippets.first { bare($0.say) == said }?.text
    }

    /// Swaps every snippet name in `text` for a placeholder. Longest name
    /// first, so "my work email" wins over "my email". Each occurrence gets
    /// its own number, so a name said twice is two placeholders and losing
    /// either is noticed.
    public static func guarded(_ snippets: [Snippet], in text: String) -> Guarded {
        var result = text
        var texts: [String] = []
        for snippet in snippets.sorted(by: { $0.say.count > $1.say.count }) {
            guard let pattern = CorrectionTable.pattern(matching: snippet.say) else { continue }
            result = result.replacing(pattern) { _ in
                texts.append(snippet.text)
                return placeholder(texts.count)
            }
        }
        return Guarded(text: result, texts: texts)
    }

    /// Whether `text` still holds every placeholder, once each. A cleanup
    /// that lost one has lost the user's snippet, and one that repeated one
    /// has written it twice; neither is used.
    public static func keptAll(_ guarded: Guarded, in text: String) -> Bool {
        let found = text.matches(of: anyPlaceholder).compactMap { Int($0.output.1) }
        return found.sorted() == guarded.texts.indices.map { $0 + 1 }
    }

    /// Puts the snippet texts back, in one pass: a text is never searched
    /// for placeholders, so a snippet may itself contain "SNIP2". Case is
    /// ignored, since a cleanup may lowercase a placeholder.
    public static func restored(_ text: String, from guarded: Guarded) -> String {
        text.replacing(anyPlaceholder) { match in
            guard let index = Int(match.output.1), guarded.texts.indices.contains(index - 1) else {
                return String(match.output.0)
            }
            return guarded.texts[index - 1]
        }
    }

    /// `text` with every snippet's text taken out: what the user said, as
    /// opposed to what a snippet wrote for them.
    public static func withoutTexts(_ snippets: [Snippet], in text: String) -> String {
        snippets.sorted(by: { $0.text.count > $1.text.count }).reduce(text) {
            $0.replacingOccurrences(of: $1.text, with: " ")
        }
    }

    private static var anyPlaceholder: Regex<(Substring, Substring)> {
        /\bSNIP(\d+)\b/.ignoresCase()
    }

    /// Lowercased words, with the punctuation the transcriber adds around
    /// them removed. Symbols inside a word are kept: "c++" stays "c++".
    private static func bare(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'“”‘’…")) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
