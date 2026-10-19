import Foundation

/// The bundled lists (GDR-0027, GDR-0028), read once from the package's
/// resource. `tools/extract-words.swift` writes that file from a
/// Wiktionary extract and the term lists in `packages/TimbreCore/Lists`;
/// the app never fetches anything. An empty resource means no bundled
/// words yet, and the word of the day comes from the Library alone.
nonisolated public enum BundledLists {

    public static let resourceName = "bundled-words"

    /// Every list in the bundle, in the order they were curated.
    public static let all: [BundledList] = {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else { return [] }
        return (try? BundledList.load(from: url)) ?? []
    }()

    /// The source and licence line the About screen shows, from the lists
    /// themselves, so the copy can never drift from the data.
    public static var attribution: String? {
        guard let first = all.first else { return nil }
        let words = all.reduce(0) { $0 + $1.words.count }
        return "\(words) words and phrases across \(all.count) lists, from \(first.source), \(first.licence)."
    }
}
