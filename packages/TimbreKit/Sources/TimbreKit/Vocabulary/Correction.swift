import Foundation

/// One taught correction: a phrase the transcriber keeps getting wrong, and
/// what the user means by it. "timber kit" → "TimbreKit". Part of the
/// personal dictionary (GDR-0011).
nonisolated public struct Correction: Codable, Sendable, Hashable, Identifiable {

    /// What the transcriber emits, as the user sees it in their pasted text.
    public let heard: String

    /// What should have been written, used verbatim.
    public let meant: String

    /// One correction per phrase: identity ignores case and spacing.
    public var id: String { Self.normalized(heard) }

    /// Nil when there is nothing to teach: an empty side, or both sides the
    /// same. A change of case alone is a real correction — "github" →
    /// "GitHub" is the commonest kind — so the comparison is exact.
    public init?(heard: String, meant: String) {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let meant = meant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !meant.isEmpty, heard != meant else { return nil }
        self.heard = heard
        self.meant = meant
    }

    static func normalized(_ phrase: String) -> String {
        phrase.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
