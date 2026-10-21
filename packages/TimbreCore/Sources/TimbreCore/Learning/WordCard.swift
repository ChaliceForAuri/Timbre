import Foundation

/// Today's word as a card (GDR-0027, property 4): the facts, each labelled
/// by where it came from — the user, the extract, Apple's dictionary, the
/// model — so a reader always knows which line is a fact and which is a
/// sketch. Pure assembly; the sources are fetched by whoever has them.
nonisolated public struct WordCard: Equatable, Sendable {

    public enum Source: String, Equatable, Sendable {
        case you
        case wiktionary
        case appleDictionary
        case model

        /// The label on the card.
        public var label: String {
            switch self {
            case .you: "Your meaning"
            case .wiktionary: "Wiktionary"
            case .appleDictionary: "Apple Dictionary"
            case .model: "Written by the model"
            }
        }
    }

    public struct Line: Equatable, Sendable {
        public let text: String
        public let source: Source

        public init(_ text: String, source: Source) {
            self.text = text
            self.source = source
        }
    }

    public let term: String
    public let kind: EntryKind?
    public let pick: DailyPick
    public let partOfSpeech: String?
    public let pronunciation: String?
    public let meanings: [Line]
    public let origin: Line?
    public let example: Line?
    public let why: String
    public let metToday: Bool
    /// Nil for a bundled word, which has no history yet.
    public let strength: Double?

    /// - Parameters:
    ///   - entry: the Library entry when the pick is one.
    ///   - appleDefinition: Apple's dictionary text and pronunciation on the
    ///     Mac, labelled as such (GDR-0028 allows the supplement there).
    ///   - example: a model-written sentence that passed `ExampleGuardrail`.
    public init(
        pick: DailyPick,
        entry: LibraryEntry?,
        appleDefinition: (text: String, pronunciation: String?)? = nil,
        example: String? = nil,
        metToday: Bool = false,
        strength: Double? = nil
    ) {
        self.pick = pick
        self.term = pick.term
        self.why = pick.why
        self.metToday = metToday
        var meanings: [Line] = []
        var origin: Line?
        var partOfSpeech: String?
        var pronunciation: String?
        switch pick.source {
        case .library:
            if let meaning = entry?.meaning { meanings.append(Line(meaning, source: .you)) }
            if let apple = appleDefinition {
                meanings.append(Line(apple.text, source: .appleDictionary))
                pronunciation = apple.pronunciation
            }
            self.kind = entry?.kind
            self.strength = strength
        case .bundled(_, let word):
            meanings.append(Line(word.definition, source: .wiktionary))
            origin = word.origin.map { Line($0, source: .wiktionary) }
            partOfSpeech = word.partOfSpeech
            pronunciation = word.pronunciation
            self.kind = nil
            self.strength = nil
        }
        self.meanings = meanings
        self.origin = origin
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        if let own = entry?.example {
            self.example = Line(own, source: .you)
        } else if let example {
            self.example = Line(example, source: .model)
        } else {
            self.example = nil
        }
    }

    /// What a notification says: the word and its first meaning.
    public var summary: String {
        guard let first = meanings.first else { return "Your word for today." }
        return "\(term) — \(first.text)"
    }
}
