import Foundation
import Observation

/// Words the user has taught the app — names, jargon, product terms.
/// Persisted across launches; fed to the polisher so the model prefers them
/// over similar-sounding alternatives. This is the differentiator: a local
/// model can learn the user's vocabulary with zero privacy cost.
///
/// A stored property (not a computed pass-through to `UserDefaults`) so that
/// `@Observable` actually observes it — mutations re-render any view reading
/// `terms`.
@Observable
final class VocabularyStore {

    private static let defaultsKey = "vocabulary"

    private let defaults: UserDefaults

    private(set) var terms: [String] {
        didSet { defaults.set(terms, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.terms = defaults.stringArray(forKey: Self.defaultsKey) ?? []
    }

    func add(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !terms.contains(trimmed) else { return }
        terms.append(trimmed)
    }

    func remove(_ term: String) {
        terms.removeAll { $0 == term }
    }
}
