import Foundation
import Observation

/// The personal dictionary: words the user has taught the app — names,
/// jargon, product terms — and corrections, what the transcriber heard against
/// what they meant. Persisted across launches. Terms go to the polisher so the
/// model prefers them over similar-sounding alternatives; corrections rewrite
/// the transcript before the model sees it (GDR-0011). This is the
/// differentiator: a local model can learn the user's vocabulary with zero
/// privacy cost.
///
/// Stored properties (not computed pass-throughs to `UserDefaults`) so that
/// `@Observable` actually observes them — mutations re-render any view reading
/// `terms` or `corrections`.
@Observable
final class VocabularyStore {

    private static let termsKey = "vocabulary"
    private static let correctionsKey = "corrections"

    private let defaults: UserDefaults

    private(set) var terms: [String] {
        didSet { defaults.set(terms, forKey: Self.termsKey) }
    }

    private(set) var corrections: [Correction] {
        didSet { defaults.set(try? JSONEncoder().encode(corrections), forKey: Self.correctionsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.terms = defaults.stringArray(forKey: Self.termsKey) ?? []
        self.corrections =
            defaults.data(forKey: Self.correctionsKey)
            .flatMap { try? JSONDecoder().decode([Correction].self, from: $0) } ?? []
    }

    func add(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !terms.contains(trimmed) else { return }
        terms.append(trimmed)
    }

    func remove(_ term: String) {
        terms.removeAll { $0 == term }
    }

    /// Teaches a correction. Re-teaching a phrase replaces what it maps to,
    /// and the corrected spelling joins `terms` so the polisher keeps it.
    /// Returns false when there was nothing to teach.
    @discardableResult
    func teach(heard: String, meant: String) -> Bool {
        guard let correction = Correction(heard: heard, meant: meant) else { return false }
        corrections.removeAll { $0.id == correction.id }
        corrections.append(correction)
        add(correction.meant)
        return true
    }

    func forget(_ correction: Correction) {
        corrections.removeAll { $0.id == correction.id }
    }
}
