import Foundation

/// What "learn" would put in the Library for a selection (GDR-0033): one
/// word, a short phrase, or nothing. Deterministic — the user is told what
/// was saved, so it must be the same every time.
nonisolated public enum LearnTarget: Equatable, Sendable {

    case word(String)
    case phrase(String)
    /// More than a phrase: a sentence or a paragraph is read, not learned.
    case tooLong
    case empty

    /// The most words a phrase to learn may have. "Separation of concerns"
    /// is three; an idiom rarely passes six.
    public static let maximumWords = 6

    private static let edges = ".,;:!?\"'“”‘’()[]{}<>…"
    private static func isEdge(_ character: Character) -> Bool { edges.contains(character) }

    public init(selection: String) {
        let words = selection.split(whereSeparator: \.isWhitespace).map(String.init)
        // The punctuation a selection drags along is not part of the term:
        // "idempotent," and "(RBAC)" are the word and the acronym.
        let edge = CharacterSet(charactersIn: Self.edges)
        // Only the outside edges: a comma between two words is the phrase's own.
        var trimmed = words.map { $0.trimmingCharacters(in: edge).isEmpty ? "" : $0 }
        trimmed.removeAll(where: \.isEmpty)
        if let first = trimmed.first { trimmed[0] = String(first.trimmingPrefix(while: Self.isEdge)) }
        if let last = trimmed.last {
            trimmed[trimmed.count - 1] = String(
                String(last.reversed()).trimmingPrefix(while: Self.isEdge).reversed())
        }
        trimmed.removeAll(where: \.isEmpty)

        switch trimmed.count {
        case 0: self = .empty
        case 1: self = .word(trimmed[0])
        case 2...Self.maximumWords: self = .phrase(trimmed.joined(separator: " "))
        default: self = .tooLong
        }
    }

    /// The entry to save, or nil when there is nothing to learn.
    public func entry(source: Provenance) -> LibraryEntry? {
        switch self {
        case .word(let term): LibraryEntry(kind: .word, term: term, source: source)
        case .phrase(let term): LibraryEntry(kind: .phrase, term: term, source: source)
        case .tooLong, .empty: nil
        }
    }
}
