import Foundation

/// One word from a bundled list: the facts, from the extract, labelled by
/// source (GDR-0028). Never written by the model.
nonisolated public struct BundledWord: Codable, Sendable, Hashable {
    public let term: String
    public let partOfSpeech: String?
    public let pronunciation: String?
    public let definition: String
    public let origin: String?
    public let parts: String?

    public init(
        term: String, partOfSpeech: String? = nil, pronunciation: String? = nil, definition: String,
        origin: String? = nil, parts: String? = nil
    ) {
        self.term = term
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        self.definition = definition
        self.origin = origin
        self.parts = parts
    }
}

/// A curated list for when the Library has nothing due (GDR-0027): general
/// English, or one industry. `industries` empty means everyone gets it.
nonisolated public struct BundledList: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let industries: [String]
    public let source: String
    public let licence: String
    public let words: [BundledWord]

    public init(
        id: String, title: String, industries: [String] = [], source: String = "Wiktionary",
        licence: String = "CC BY-SA 4.0", words: [BundledWord]
    ) {
        self.id = id
        self.title = title
        self.industries = industries
        self.source = source
        self.licence = licence
        self.words = words
    }

    public static func load(from url: URL) throws -> [BundledList] {
        try JSONDecoder().decode([BundledList].self, from: Data(contentsOf: url))
    }
}
