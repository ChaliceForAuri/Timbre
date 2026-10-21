import Foundation
import Observation

/// The Library (GDR-0023): one store, five kinds. Words the polisher should
/// prefer, corrections that run before the model (GDR-0011), definitions
/// that answer explain first (GDR-0012), phrases and spellings to practise —
/// each an entry with a meaning, an example, where it came from, and a
/// history that strength is derived from (ADR-0014).
///
/// Persisted as one versioned JSON document (ADR-0013), written whole and
/// atomically; small enough that this is the simplest correct thing. Sync
/// goes through `LibrarySync` and `merge(entries:events:)`, never through
/// the file. Nothing in here is ever a dictation (GDR-0004).
@Observable
public final class Library {

    public static let schemaVersion = 1

    /// Insertion order, which is the order Settings shows.
    public private(set) var entries: [LibraryEntry] = []
    /// Every event, every entry, in no particular order; `history(of:)`
    /// orders them.
    public private(set) var events: [LibraryEvent] = []
    public var profile = Profile.empty {
        didSet { save() }
    }
    /// The last failure to write the file, for Settings to show. Nil when
    /// the last save succeeded.
    public private(set) var lastSaveError: Error?

    private var legacyImported = false
    private var loading = true
    private let fileURL: URL
    private let device: Device

    /// `~/Library/Application Support/Timbre/library.json` on the Mac; the
    /// app's own container elsewhere.
    public static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(filePath: NSHomeDirectory())
        return base.appending(path: "Timbre", directoryHint: .isDirectory).appending(path: "library.json")
    }

    /// Loads the document at `fileURL` if there is one. The first time, the
    /// three lists the Mac kept in `legacy` — vocabulary, corrections,
    /// acronyms — become entries, in order, with nothing lost; the old keys
    /// are left alone.
    public init(fileURL: URL, device: Device = .mac, legacy: UserDefaults? = .standard) {
        self.fileURL = fileURL
        self.device = device
        if let data = try? Data(contentsOf: fileURL),
            let document = try? Self.makeDecoder().decode(LibraryDocument.self, from: data)
        {
            entries = document.entries
            events = document.events
            profile = document.profile
            legacyImported = document.legacyImported
        }
        if !legacyImported {
            if let legacy { importLegacy(from: legacy) }
            legacyImported = true
        }
        loading = false
        save()
    }

    // MARK: - The three lists, as the pipeline and Settings read them

    /// Words the user has taught, in order. Handed to the polisher.
    public var terms: [String] {
        entries.filter { $0.kind == .word }.map(\.term)
    }

    /// What Timbre heard against what the user meant (GDR-0011).
    public var corrections: [Correction] {
        entries.filter { $0.kind == .correction }.compactMap {
            Correction(heard: $0.heard ?? "", meant: $0.term)
        }
    }

    /// Terms with a taught meaning; they answer explain first (GDR-0012).
    public var acronyms: [Acronym] {
        entries.filter { $0.kind == .acronym }.compactMap {
            Acronym(term: $0.term, meaning: $0.meaning ?? "")
        }
    }

    public func add(_ term: String) {
        add(term, how: .typed)
    }

    /// A word, with where it came from. Adding a word that is already in the
    /// Library changes nothing.
    public func add(_ term: String, how: Provenance.How, app: String? = nil, on date: Date = Date()) {
        guard let entry = LibraryEntry(kind: .word, term: term, source: provenance(how, app: app, on: date)),
            !entries.contains(where: { $0.id == entry.id })
        else { return }
        upsert(entry, on: date)
    }

    public func remove(_ term: String) {
        forget(entryID: LibraryEntry.id(kind: .word, term: term))
    }

    /// Teaches a correction. Re-teaching a phrase replaces what it maps to,
    /// and the corrected spelling joins the words so the polisher keeps it.
    /// False when there was nothing to teach.
    @discardableResult
    public func teach(heard: String, meant: String, on date: Date = Date()) -> Bool {
        guard let correction = Correction(heard: heard, meant: meant),
            let entry = LibraryEntry(
                kind: .correction, term: correction.meant, heard: correction.heard,
                source: provenance(.corrected, on: date))
        else { return false }
        upsert(entry, on: date)
        add(correction.meant, how: .corrected, on: date)
        return true
    }

    public func forget(_ correction: Correction) {
        forget(entryID: LibraryEntry.id(kind: .correction, term: correction.meant, heard: correction.heard))
    }

    /// Defines a term; redefining one replaces its meaning. False when there
    /// was nothing to define.
    @discardableResult
    public func define(term: String, meaning: String, on date: Date = Date()) -> Bool {
        guard let acronym = Acronym(term: term, meaning: meaning),
            let entry = LibraryEntry(
                kind: .acronym, term: acronym.term, meaning: acronym.meaning,
                source: provenance(.typed, on: date))
        else { return false }
        upsert(entry, on: date)
        return true
    }

    public func undefine(_ acronym: Acronym) {
        forget(entryID: LibraryEntry.id(kind: .acronym, term: acronym.term))
    }

    // MARK: - Entries and events

    public func entry(_ id: String) -> LibraryEntry? {
        entries.first { $0.id == id }
    }

    /// Adds an entry, or replaces the one with its id in place, keeping its
    /// history. A new entry gets a `taught` event.
    public func upsert(_ entry: LibraryEntry, on date: Date = Date()) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            var updated = entry
            updated.edited = date
            entries[index] = updated
            save()
        } else {
            entries.append(entry)
            record(.taught, for: entry.id, on: date)
        }
    }

    /// Removes an entry and leaves a tombstone, so the removal outlives a
    /// sync race (GDR-0023, decision 1).
    public func forget(entryID id: String, on date: Date = Date()) {
        guard entries.contains(where: { $0.id == id }) else { return }
        entries.removeAll { $0.id == id }
        record(.forgot, for: id, on: date)
    }

    /// Appends an event, once: the same thing happening at the same second
    /// is one event. Saves.
    @discardableResult
    public func record(
        _ kind: LibraryEvent.Kind, for entryID: String, app: String? = nil, drill: Drill? = nil,
        on date: Date = Date()
    ) -> LibraryEvent {
        let event = LibraryEvent(
            entry: entryID, kind: kind, date: date, device: device, app: app, drill: drill)
        if !events.contains(where: { $0.id == event.id }) {
            events.append(event)
        }
        save()
        return event
    }

    /// An entry's events, oldest first.
    public func history(of entryID: String) -> [LibraryEvent] {
        LibraryEvent.ordered(events.filter { $0.entry == entryID })
    }

    /// The chance of recalling the entry now (ADR-0014). 0 with no history.
    public func strength(of entryID: String, at date: Date = Date()) -> Double {
        Strength.strength(of: history(of: entryID), at: date)
    }

    /// Has a history and has faded below the target (ADR-0014).
    public func isDue(_ entryID: String, at date: Date = Date()) -> Bool {
        Strength.isDue(history(of: entryID), at: date)
    }

    // MARK: - The word of the day (GDR-0027)

    public func wordOfTheDay(
        on day: Date = Date(), bundled: [BundledList] = [], calendar: Calendar = .current
    ) -> DailyPick? {
        DailyPicker.pick(
            entries: entries, events: events, profile: profile, bundled: bundled, on: day, calendar: calendar)
    }

    /// Today's word, met in the wild: when `text` contains it, records that
    /// — once a day, with the app, never the text. True when it did.
    @discardableResult
    public func noteMet(
        in text: String, app: String?, on date: Date = Date(), bundled: [BundledList] = [],
        calendar: Calendar = .current
    ) -> Bool {
        guard let pick = wordOfTheDay(on: date, bundled: bundled, calendar: calendar),
            case .library(let entryID, _) = pick.source,
            MetDetector.contains(pick.term, in: text)
        else { return false }
        let metToday = events.contains {
            $0.entry == entryID && $0.kind == .met && calendar.isDate($0.date, inSameDayAs: date)
        }
        guard !metToday else { return false }
        record(.met, for: entryID, app: app, on: date)
        return true
    }

    // MARK: - Sync and export

    /// Takes in another device's copy: events union, entries by latest edit,
    /// tombstones honoured (`LibraryMerge`).
    public func merge(entries remoteEntries: [LibraryEntry], events remoteEvents: [LibraryEvent]) {
        events = LibraryMerge.events(events, remoteEvents)
        entries = LibraryMerge.entries(entries, remoteEntries, events: events)
        save()
    }

    /// The whole Library as the file holds it, for anyone who declines iCloud
    /// (GDR-0010).
    public func export() throws -> Data {
        try Self.makeEncoder().encode(document)
    }

    /// Takes in an exported file — from another Mac, or from a backup — by
    /// the same merge rule sync uses. Returns how much it knew already.
    @discardableResult
    public func importDocument(_ data: Data) throws -> (entries: Int, events: Int) {
        let document = try Self.makeDecoder().decode(LibraryDocument.self, from: data)
        guard document.schema <= Self.schemaVersion else { throw ImportError.newerSchema(document.schema) }
        let known = (entries: entries.count, events: events.count)
        merge(entries: document.entries, events: document.events)
        return (entries.count - known.entries, events.count - known.events)
    }

    public enum ImportError: Error, Equatable {
        /// Written by a newer Timbre; this one cannot read it safely.
        case newerSchema(Int)
    }

    /// Called after every successful write, so a surface can follow the
    /// Library without polling: the word of the day rebuilds its card, the
    /// sync queues what changed. Several may listen.
    public func addSaveObserver(_ observer: @escaping @MainActor () -> Void) {
        saveObservers.append(observer)
    }

    private var saveObservers: [@MainActor () -> Void] = []

    // MARK: - Persistence

    private var document: LibraryDocument {
        LibraryDocument(
            schema: Self.schemaVersion, entries: entries, events: events, profile: profile,
            legacyImported: legacyImported)
    }

    private func save() {
        guard !loading else { return }
        do {
            let data = try Self.makeEncoder().encode(document)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            lastSaveError = nil
            for observer in saveObservers { observer() }
        } catch {
            lastSaveError = error
        }
    }

    private func importLegacy(from defaults: UserDefaults, on date: Date = Date()) {
        let source = provenance(.imported, on: date)
        for term in defaults.stringArray(forKey: "vocabulary") ?? [] {
            if let entry = LibraryEntry(kind: .word, term: term, source: source) { append(entry, on: date) }
        }
        let corrections =
            defaults.data(forKey: "corrections").flatMap {
                try? JSONDecoder().decode([Correction].self, from: $0)
            }
            ?? []
        for correction in corrections {
            if let entry = LibraryEntry(
                kind: .correction, term: correction.meant, heard: correction.heard, source: source)
            {
                append(entry, on: date)
            }
        }
        let acronyms =
            defaults.data(forKey: "acronyms").flatMap { try? JSONDecoder().decode([Acronym].self, from: $0) }
            ?? []
        for acronym in acronyms {
            if let entry = LibraryEntry(
                kind: .acronym, term: acronym.term, meaning: acronym.meaning, source: source)
            {
                append(entry, on: date)
            }
        }
    }

    private func append(_ entry: LibraryEntry, on date: Date) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        events.append(LibraryEvent(entry: entry.id, kind: .taught, date: date, device: device))
    }

    private func provenance(_ how: Provenance.How, app: String? = nil, on date: Date) -> Provenance {
        Provenance(device: device, date: date, how: how, app: app)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// The file on disk, versioned. Fields are only ever added (ADR-0013).
nonisolated struct LibraryDocument: Codable, Sendable {
    var schema: Int
    var entries: [LibraryEntry]
    var events: [LibraryEvent]
    var profile: Profile
    var legacyImported: Bool
}
