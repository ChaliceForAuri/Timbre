import Foundation

/// A term the user has defined: "ADR" means "Architecture Decision Record".
/// Part of the personal dictionary; it answers "explain" before the model
/// does (GDR-0012), because the model does not know the user's jargon and,
/// measured, does not say so — it invents an expansion instead.
nonisolated public struct Acronym: Codable, Sendable, Hashable, Identifiable {

    public let term: String
    public let meaning: String

    /// One definition per term, exactly as written: "IT" is not "it".
    public var id: String { term }

    public init?(term: String, meaning: String) {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !meaning.isEmpty else { return nil }
        self.term = term
        self.meaning = meaning
    }
}

/// Finds taught terms in a selection. Whole words, case-sensitive: an
/// acronym is its capitals.
nonisolated enum AcronymTable {

    /// The taught answer when the selection *is* a taught term, give or take
    /// the punctuation and whitespace that came along with it.
    static func exactAnswer(for selection: String, from acronyms: [Acronym]) -> String? {
        let bare = selection.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard let match = acronyms.first(where: { $0.term == bare }) else { return nil }
        return "\(match.term) — \(match.meaning)"
    }

    /// Taught terms appearing in `text`, in the order they were taught.
    static func matches(in text: String, from acronyms: [Acronym]) -> [Acronym] {
        acronyms.filter { acronym in
            guard let pattern = pattern(matching: acronym.term) else { return false }
            return text.contains(pattern)
        }
    }

    private static func pattern(matching term: String) -> Regex<AnyRegexOutput>? {
        guard let first = term.first, let last = term.last else { return nil }
        let lead = first.isLetter || first.isNumber ? "\\b" : ""
        let trail = last.isLetter || last.isNumber ? "\\b" : ""
        return try? Regex(lead + NSRegularExpression.escapedPattern(for: term) + trail)
    }
}
