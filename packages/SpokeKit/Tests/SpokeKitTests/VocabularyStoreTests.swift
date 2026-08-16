import Foundation
import Testing

@testable import SpokeKit

struct VocabularyStoreTests {

    /// Each test gets its own defaults suite so runs can't contaminate each
    /// other or the developer's real vocabulary.
    private func makeIsolatedDefaults() -> (UserDefaults, cleanup: () -> Void) {
        let suiteName = "SpokeKitTests-\(UUID().uuidString)"
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
        store.add("Spoke")
        store.add("Spoke")
        #expect(store.terms == ["Spoke"])
    }

    @Test func removes() {
        let (defaults, cleanup) = makeIsolatedDefaults()
        defer { cleanup() }

        let store = VocabularyStore(defaults: defaults)
        store.add("Spoke")
        store.add("Wispr")
        store.remove("Spoke")
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
