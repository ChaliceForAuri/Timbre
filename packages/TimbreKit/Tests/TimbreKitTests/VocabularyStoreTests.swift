import Foundation
import Testing

@testable import TimbreKit

struct VocabularyStoreTests {

    /// Each test gets its own defaults suite so runs can't contaminate each
    /// other or the developer's real vocabulary.
    private func makeIsolatedDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let suiteName = "TimbreKitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    @Test func addsATrimmedTerm() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.add("  SwiftUI  ")
        #expect(store.terms == ["SwiftUI"])
    }

    @Test func rejectsEmptyAndWhitespaceTerms() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.add("")
        store.add("   ")
        #expect(store.terms.isEmpty)
    }

    @Test func deduplicates() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.add("Timbre")
        store.add("Timbre")
        #expect(store.terms == ["Timbre"])
    }

    @Test func removes() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.add("Timbre")
        store.add("Wispr")
        store.remove("Timbre")
        #expect(store.terms == ["Wispr"])
    }

    @Test func persistsAcrossInstances() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        VocabularyStore(defaults: defaults).add("Anthropic")
        let reloaded = VocabularyStore(defaults: defaults)
        #expect(reloaded.terms == ["Anthropic"])
    }
}
