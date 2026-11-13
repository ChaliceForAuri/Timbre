import Foundation

/// What Settings shows of the Library: one kind or all, and a search over
/// the term, the heard phrase, the meaning and the tags. Case and diacritics
/// are ignored, so "cafe" finds "café".
nonisolated public struct LibraryQuery: Equatable, Sendable {

    public var kind: EntryKind?
    public var search: String

    public init(kind: EntryKind? = nil, search: String = "") {
        self.kind = kind
        self.search = search
    }

    public func matches(_ entry: LibraryEntry) -> Bool {
        if let kind, entry.kind != kind { return false }
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystacks = [entry.term, entry.heard, entry.meaning].compactMap { $0 } + entry.tags
        return haystacks.contains {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    public func apply(to entries: [LibraryEntry]) -> [LibraryEntry] {
        entries.filter(matches)
    }
}
