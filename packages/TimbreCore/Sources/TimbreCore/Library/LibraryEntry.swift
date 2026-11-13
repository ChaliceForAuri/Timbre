import Foundation

/// What kind of thing an entry is. Five, exactly (GDR-0023, decision 3); a
/// sixth needs a drill that can score it.
nonisolated public enum EntryKind: String, Codable, Sendable, CaseIterable {
    case word
    case acronym
    case phrase
    case spelling
    case correction

    /// The kinds practice and the word of the day draw on. A correction is a
    /// mis-hearing to repair, not a word to learn.
    public var isLearnable: Bool { self != .correction }
}

/// Which of the user's devices did something.
nonisolated public enum Device: String, Codable, Sendable {
    case mac
    case iPhone
    case watch
}

/// Where an entry came from: the device, the day, how, and the app it was
/// met in. Never the sentence it was met in (GDR-0004).
nonisolated public struct Provenance: Codable, Sendable, Hashable {

    public enum How: String, Codable, Sendable {
        case dictated
        case typed
        case explained
        case corrected
        case bundled
        case imported
    }

    public let device: Device
    public let date: Date
    public let how: How
    public let app: String?

    public init(device: Device, date: Date, how: How, app: String? = nil) {
        self.device = device
        self.date = date
        self.how = how
        self.app = app
    }
}

/// One entry in the Library (GDR-0023): the term, what it means, an example,
/// where it came from, its tags, and when it was last edited. Its strength
/// is not here — it is derived from the entry's events (ADR-0014).
///
/// `term` is the thing itself: the word, the acronym, the phrase, the correct
/// spelling, or — for a correction — what the user meant. `heard` is the
/// other side where there is one: the phrase the transcriber emits, or the
/// misspelling.
nonisolated public struct LibraryEntry: Codable, Sendable, Hashable, Identifiable {

    public let id: String
    public let kind: EntryKind
    public var term: String
    public var heard: String?
    public var meaning: String?
    public var example: String?
    public var tags: [String]
    public var source: Provenance
    public var edited: Date

    /// Nil when there is nothing to keep: an empty term, a correction with no
    /// heard side or one equal to the term, an acronym with no meaning.
    public init?(
        kind: EntryKind,
        term: String,
        heard: String? = nil,
        meaning: String? = nil,
        example: String? = nil,
        tags: [String] = [],
        source: Provenance,
        edited: Date? = nil
    ) {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let heard = heard?.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaning = meaning?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return nil }
        switch kind {
        case .correction:
            guard let heard, !heard.isEmpty, heard != term else { return nil }
        case .acronym:
            guard let meaning, !meaning.isEmpty else { return nil }
        case .word, .phrase, .spelling:
            break
        }
        self.id = Self.id(kind: kind, term: term, heard: heard)
        self.kind = kind
        self.term = term
        self.heard = heard?.nonEmpty
        self.meaning = meaning?.nonEmpty
        self.example = example?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.tags = tags
        self.source = source
        self.edited = edited ?? source.date
    }

    /// One entry per thing. A word, phrase or spelling ignores case and
    /// spacing; an acronym is its capitals ("IT" is not "it"); a correction
    /// is its heard phrase, so two heard phrases may mean the same word.
    public static func id(kind: EntryKind, term: String, heard: String? = nil) -> String {
        switch kind {
        case .acronym:
            return "acronym:" + term.trimmingCharacters(in: .whitespacesAndNewlines)
        case .correction:
            return "correction:" + normalized(heard ?? "")
        case .word, .phrase, .spelling:
            return kind.rawValue + ":" + normalized(term)
        }
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: Codable — optional fields may be absent in a corpus or an export.

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case term
        case heard
        case meaning
        case example
        case tags
        case source
        case edited
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(EntryKind.self, forKey: .kind)
        term = try container.decode(String.self, forKey: .term)
        heard = try container.decodeIfPresent(String.self, forKey: .heard)
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning)
        example = try container.decodeIfPresent(String.self, forKey: .example)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        source =
            try container.decodeIfPresent(Provenance.self, forKey: .source)
            ?? Provenance(device: .mac, date: .distantPast, how: .typed)
        edited = try container.decodeIfPresent(Date.self, forKey: .edited) ?? source.date
        id =
            try container.decodeIfPresent(String.self, forKey: .id)
            ?? Self.id(kind: kind, term: term, heard: heard)
    }
}

extension String {
    /// Nil for the empty string, so an absent field and a blank one are the
    /// same thing in an entry.
    nonisolated var nonEmpty: String? { isEmpty ? nil : self }
}
