import Foundation
import Testing

@testable import TimbreCore

struct LibraryTests {

    /// Each test gets its own file and its own defaults suite, so runs cannot
    /// contaminate each other or the developer's real Library.
    private func makeIsolated() -> (file: URL, defaults: UserDefaults, cleanup: () -> Void) {
        let suite = "TimbreCoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = URL(filePath: NSTemporaryDirectory()).appending(
            path: suite, directoryHint: .isDirectory)
        let file = directory.appending(path: "library.json")
        let cleanup = {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        return (file, defaults, cleanup)
    }

    private func days(_ count: Double, before date: Date = Date()) -> Date {
        date.addingTimeInterval(-count * 86400)
    }

    // MARK: Words

    @Test func addsATrimmedTerm() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("  SwiftUI  ")
        #expect(library.terms == ["SwiftUI"])
    }

    @Test func rejectsEmptyAndWhitespaceTerms() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("")
        library.add("   ")
        #expect(library.terms.isEmpty)
        #expect(library.events.isEmpty)
    }

    @Test func deduplicatesIgnoringCase() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("Timbre")
        library.add("timbre")
        #expect(library.terms == ["Timbre"])
        #expect(library.events.count == 1)
    }

    @Test func removesAndLeavesATombstone() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("Timbre")
        library.add("Wispr")
        library.remove("Timbre")
        #expect(library.terms == ["Wispr"])
        #expect(library.events.map(\.kind) == [.taught, .taught, .forgot])
    }

    @Test func persistsAcrossInstances() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        Library(fileURL: file, legacy: defaults).add("Anthropic")
        let reloaded = Library(fileURL: file, legacy: defaults)
        #expect(reloaded.terms == ["Anthropic"])
        #expect(reloaded.events.count == 1)
    }

    // MARK: Corrections

    @Test func teachingAlsoAddsTheCorrectedSpellingToTerms() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        #expect(library.teach(heard: " timber kit ", meant: "TimbreKit"))
        #expect(library.corrections.map(\.heard) == ["timber kit"])
        #expect(library.terms == ["TimbreKit"])
    }

    @Test func reteachingAPhraseReplacesItsMeaning() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.teach(heard: "timber kit", meant: "Timberkit")
        library.teach(heard: "Timber  Kit", meant: "TimbreKit")
        #expect(library.corrections.count == 1)
        #expect(library.corrections.first?.meant == "TimbreKit")
    }

    @Test func rejectsEmptySidesAndSelfCorrections() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        #expect(!library.teach(heard: "", meant: "x"))
        #expect(!library.teach(heard: "x", meant: "  "))
        #expect(!library.teach(heard: " same ", meant: "same"))
        #expect(library.corrections.isEmpty)
    }

    /// The commonest correction of all is capitalisation.
    @Test func aChangeOfCaseAloneIsACorrection() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        #expect(library.teach(heard: "github", meant: "GitHub"))
        #expect(CorrectionTable.applied(library.corrections, to: "push to github") == "push to GitHub")
    }

    @Test func forgettingACorrectionPersists() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        Library(fileURL: file, legacy: defaults).teach(heard: "evils", meant: "evals")
        let reloaded = Library(fileURL: file, legacy: defaults)
        #expect(reloaded.corrections.map(\.meant) == ["evals"])
        reloaded.forget(reloaded.corrections[0])
        #expect(reloaded.corrections.isEmpty)
        #expect(Library(fileURL: file, legacy: defaults).corrections.isEmpty)
    }

    // MARK: Definitions

    @Test func definingPersistsAndRedefiningReplaces() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        #expect(!library.define(term: " ", meaning: "nothing"))
        library.define(term: "ADR", meaning: "Alternative Dispute Resolution")
        library.define(term: "ADR", meaning: "Architecture Decision Record")

        let reloaded = Library(fileURL: file, legacy: defaults)
        #expect(reloaded.acronyms.map(\.meaning) == ["Architecture Decision Record"])
        reloaded.undefine(reloaded.acronyms[0])
        #expect(Library(fileURL: file, legacy: defaults).acronyms.isEmpty)
    }

    // MARK: Migration (GDR-0023: nothing lost, nothing asked)

    @Test func theOldListsMigrateOnceAndStayWhereTheyWere() throws {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        defaults.set(["SwiftUI", "Supabase"], forKey: "vocabulary")
        defaults.set(
            try JSONEncoder().encode([Correction(heard: "timber kit", meant: "TimbreKit")!]),
            forKey: "corrections")
        defaults.set(
            try JSONEncoder().encode([Acronym(term: "ADR", meaning: "Architecture Decision Record")!]),
            forKey: "acronyms")

        let library = Library(fileURL: file, legacy: defaults)
        #expect(library.terms == ["SwiftUI", "Supabase"])
        #expect(library.corrections.map(\.heard) == ["timber kit"])
        #expect(library.acronyms.map(\.term) == ["ADR"])
        #expect(library.entries.allSatisfy { $0.source.how == .imported })

        // A removal after the import is not undone by the next launch.
        library.remove("SwiftUI")
        let relaunched = Library(fileURL: file, legacy: defaults)
        #expect(relaunched.terms == ["Supabase"])
        // And the old lists are untouched, for a downgrade.
        #expect(defaults.stringArray(forKey: "vocabulary") == ["SwiftUI", "Supabase"])
    }

    // MARK: Strength, the word of the day, met

    @Test func aTaughtWordStartsFullAndFades() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        let taught = days(10)
        library.add("ephemeral", how: .typed, on: taught)
        let id = LibraryEntry.id(kind: .word, term: "ephemeral")
        #expect(abs(library.strength(of: id, at: taught) - 1) < 1e-6)
        #expect(library.strength(of: id, at: days(0)) < Strength.targetRetention)
        #expect(library.strength(of: "word:unknown") == 0)
    }

    @Test func todaysWordIsMetOnceADay() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("ephemeral", how: .typed, on: days(6))
        let pick = library.wordOfTheDay()
        #expect(pick?.term == "ephemeral")

        #expect(library.noteMet(in: "Fame is Ephemeral, she said.", app: "Mail"))
        #expect(!library.noteMet(in: "ephemeral again", app: "Mail"))
        #expect(!library.noteMet(in: "ephemerally", app: "Mail"))
        let met = library.events.filter { $0.kind == .met }
        #expect(met.count == 1)
        #expect(met.first?.app == "Mail")
    }

    @Test func nothingDueAndNothingBundledMeansNoWord() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("fresh")
        #expect(library.wordOfTheDay() == nil)
        #expect(!library.noteMet(in: "fresh", app: nil))
    }

    // MARK: Merge and export

    @Test func mergingTakesTheUnion() {
        let (fileA, defaultsA, cleanupA) = makeIsolated()
        defer { cleanupA() }
        let (fileB, defaultsB, cleanupB) = makeIsolated()
        defer { cleanupB() }
        let mac = Library(fileURL: fileA, device: .mac, legacy: defaultsA)
        let phone = Library(fileURL: fileB, device: .iPhone, legacy: defaultsB)
        mac.teach(heard: "timber kit", meant: "TimbreKit")
        phone.define(term: "ADR", meaning: "Architecture Decision Record")
        phone.add("TimbreKit")

        mac.merge(entries: phone.entries, events: phone.events)
        #expect(mac.terms == ["TimbreKit"])
        #expect(mac.acronyms.map(\.term) == ["ADR"])
        #expect(Set(mac.events.map(\.id)) == Set(mac.events.map(\.id)).union(phone.events.map(\.id)))
        mac.merge(entries: phone.entries, events: phone.events)
        #expect(mac.entries.count == 3)
    }

    @Test func importingAnExportMergesByTheSyncRule() throws {
        let (fileA, defaultsA, cleanupA) = makeIsolated()
        defer { cleanupA() }
        let (fileB, defaultsB, cleanupB) = makeIsolated()
        defer { cleanupB() }
        // Explicit seconds: two devices teaching the same word in the same
        // second would be one event, by design.
        let mac = Library(fileURL: fileA, device: .mac, legacy: defaultsA)
        mac.add("ephemeral", how: .typed, on: Date(timeIntervalSince1970: 1_000_000))
        let other = Library(fileURL: fileB, device: .mac, legacy: defaultsB)
        other.add("tacit", how: .typed, on: Date(timeIntervalSince1970: 1_000_010))
        other.add("ephemeral", how: .typed, on: Date(timeIntervalSince1970: 1_000_020))

        let added = try mac.importDocument(other.export())
        #expect(added.entries == 1)
        #expect(added.events == 2)
        #expect(mac.terms == ["ephemeral", "tacit"])
        #expect(try mac.importDocument(other.export()) == (entries: 0, events: 0))
    }

    @Test func aNewerFileIsRefused() throws {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        let newer = Data(
            "{\"schema\": 99, \"entries\": [], \"events\": [], \"profile\": {\"industries\": []}, \"legacyImported\": true}"
                .utf8)
        #expect(throws: Library.ImportError.newerSchema(99)) { try library.importDocument(newer) }
    }

    @Test func didSaveFiresAfterEveryWrite() {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        var saves = 0
        library.didSave = { saves += 1 }
        library.add("one")
        library.remove("one")
        #expect(saves == 2)
    }

    @Test func exportIsTheDocument() throws {
        let (file, defaults, cleanup) = makeIsolated()
        defer { cleanup() }
        let library = Library(fileURL: file, legacy: defaults)
        library.add("exported")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(LibraryDocument.self, from: library.export())
        #expect(document.schema == Library.schemaVersion)
        #expect(document.entries.map(\.term) == ["exported"])
        #expect(document.legacyImported)
    }
}
