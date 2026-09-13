import Foundation
import Testing

@testable import TimbreKit

struct CorrectionTeachingTests {

    private func makeIsolatedDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let suiteName = "TimbreKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    @Test func teachingAlsoAddsTheCorrectedSpellingToTerms() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        #expect(store.teach(heard: " timber kit ", meant: "TimbreKit"))
        #expect(store.corrections.map(\.heard) == ["timber kit"])
        #expect(store.terms == ["TimbreKit"])
    }

    @Test func reteachingAPhraseReplacesItsMeaning() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.teach(heard: "timber kit", meant: "Timberkit")
        store.teach(heard: "Timber  Kit", meant: "TimbreKit")
        #expect(store.corrections.count == 1)
        #expect(store.corrections.first?.meant == "TimbreKit")
    }

    @Test func rejectsEmptySidesAndSelfCorrections() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        #expect(!store.teach(heard: "", meant: "x"))
        #expect(!store.teach(heard: "x", meant: "  "))
        #expect(!store.teach(heard: " same ", meant: "same"))
        #expect(store.corrections.isEmpty)
    }

    /// The commonest correction of all is capitalisation.
    @Test func aChangeOfCaseAloneIsACorrection() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        #expect(store.teach(heard: "github", meant: "GitHub"))
        #expect(CorrectionTable.applied(store.corrections, to: "push to github") == "push to GitHub")
    }

    @Test func forgettingAndPersistence() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        VocabularyStore(defaults: defaults).teach(heard: "evils", meant: "evals")
        let reloaded = VocabularyStore(defaults: defaults)
        #expect(reloaded.corrections.map(\.meant) == ["evals"])

        reloaded.forget(reloaded.corrections[0])
        #expect(reloaded.corrections.isEmpty)
        #expect(VocabularyStore(defaults: defaults).corrections.isEmpty)
    }
}
