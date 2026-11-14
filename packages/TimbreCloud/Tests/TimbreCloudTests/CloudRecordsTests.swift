import CloudKit
import Foundation
import Testing
import TimbreCore

@testable import TimbreCloud

struct CloudRecordsTests {

    private let source = Provenance(
        device: .iPhone, date: Date(timeIntervalSince1970: 1_700_000_000), how: .dictated, app: "Mail")
    private let key = Data(repeating: 7, count: 32)

    @Test func anEventRoundTrips() {
        let event = LibraryEvent(
            entry: "word:ephemeral", kind: .passed, date: Date(timeIntervalSince1970: 1_700_000_100),
            device: .watch,
            app: nil, drill: .spellIt)
        let record = CloudRecords.record(for: event, key: key)
        #expect(record.recordID.recordName == CloudRecords.name(for: event.id, key: key))
        #expect(record.recordID.zoneID.zoneName == "Library")
        #expect(CloudRecords.event(from: record) == event)
    }

    @Test func anEntryRoundTripsWithEveryField() {
        var entry = LibraryEntry(
            kind: .acronym, term: "ADR", meaning: "Architecture Decision Record", example: "We wrote an ADR.",
            tags: ["software"], source: source)!
        entry.edited = Date(timeIntervalSince1970: 1_700_000_500)
        let back = CloudRecords.entry(from: CloudRecords.record(for: entry, key: key))
        #expect(back == entry)
        #expect(back?.source.app == "Mail")
    }

    @Test func theProfileRoundTrips() {
        let profile = Profile(
            industries: ["software", "product"], role: "engineer", firstLanguage: "English")
        #expect(CloudRecords.profile(from: CloudRecords.record(for: profile)) == profile)
        #expect(CloudRecords.profile(from: CloudRecords.record(for: .empty)) == .empty)
    }

    @Test func aRecordOfAnotherTypeIsRefused() {
        let stray = CKRecord(
            recordType: "Something", recordID: CKRecord.ID(recordName: "x", zoneID: CloudRecords.zoneID))
        #expect(CloudRecords.event(from: stray) == nil)
        #expect(CloudRecords.entry(from: stray) == nil)
        #expect(CloudRecords.profile(from: stray) == nil)
    }

    @Test func systemFieldsRoundTrip() {
        let record = CloudRecords.record(for: Profile(industries: ["law"]))
        let data = CloudRecords.systemFields(of: record)
        let back = CloudRecords.record(fromSystemFields: data)
        #expect(back?.recordID == record.recordID)
        #expect(back?.recordType == CloudRecords.profileType)
        // System fields only: the values were not carried.
        #expect(back?["industries"] == nil)
    }

    @Test func syncStatePersists() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "library-sync.json")
        var state = SyncState()
        state.nameKey = Data(repeating: 1, count: 32)
        state.keyConfirmed = true
        state.pushedEvents = ["ab12"]
        state.pushedEntryEdits = ["cd34": Date(timeIntervalSince1970: 1_700_000_000)]
        state.pushedProfile = Profile(industries: ["law"], role: nil, firstLanguage: nil)
        try state.save(to: url)
        #expect(SyncState.load(from: url) == state)
        #expect(SyncState.load(from: directory.appending(path: "missing.json")) == SyncState())
    }

    @Test("A state file from before ADR-0018 is not read: the sync starts again")
    func anOldStateFileIsDropped() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "library-sync.json")
        let old = #"{"pushedEventIDs":["taught|word:a|1|mac||"],"pushedEntryEdits":{},"systemFields":{}}"#
        try Data(old.utf8).write(to: url)
        #expect(SyncState.load(from: url) == SyncState())
    }
}

/// GDR-0031: nothing the user wrote is readable on the server.
struct EncryptedSchemaTests {

    private let key = Data(repeating: 7, count: 32)
    private let source = Provenance(
        device: .mac, date: Date(timeIntervalSince1970: 1_700_000_000), how: .typed, app: "Notes")

    @Test("No record carries a plain field: every value is an encrypted value")
    func noPlainFields() {
        var entry = LibraryEntry(
            kind: .acronym, term: "ADR", heard: "a d r", meaning: "Architecture Decision Record",
            example: "We wrote an ADR.", tags: ["software"], source: source)!
        entry.edited = Date(timeIntervalSince1970: 1_700_000_500)
        let event = LibraryEvent(
            entry: entry.id, kind: .passed, date: Date(timeIntervalSince1970: 1_700_000_100), device: .mac,
            app: "Notes", drill: .sayIt)
        let profile = Profile(industries: ["software"], role: "engineer", firstLanguage: "Afrikaans")
        let records = [
            CloudRecords.record(for: entry, key: key), CloudRecords.record(for: event, key: key),
            CloudRecords.record(for: profile),
            CloudRecords.fill(
                CKRecord(
                    recordType: CloudRecords.keyType, recordID: CloudRecords.recordID(CloudRecords.keyName)),
                withNameKey: key),
        ]
        for record in records {
            // `allKeys` lists plain and encrypted keys alike; what is left
            // after taking the encrypted ones away is what the server reads.
            let plain = Set(record.allKeys()).subtracting(record.encryptedValues.allKeys())
            #expect(plain.isEmpty, "\(record.recordType) has plain fields \(plain)")
            #expect(!record.encryptedValues.allKeys().isEmpty)
        }
    }

    @Test("A record's name is a keyed hash: it holds neither the term nor the id")
    func namesAreOpaque() {
        let entry = LibraryEntry(kind: .word, term: "ephemeral", source: source)!
        let name = CloudRecords.record(for: entry, key: key).recordID.recordName
        #expect(name.count == 64)
        #expect(name.allSatisfy { $0.isHexDigit })
        #expect(!name.contains("ephemeral"))
        // The same id under the same key is the same record on every device…
        #expect(name == CloudRecords.name(for: entry.id, key: key))
        // …and under another key it is unrecognisable, so a name cannot be
        // guessed by hashing a dictionary.
        #expect(name != CloudRecords.name(for: entry.id, key: Data(repeating: 8, count: 32)))
    }

    @Test func theNameKeyRoundTripsAndAWrongSizeIsRefused() {
        let fresh = CloudRecords.newNameKey()
        #expect(fresh.count == 32)
        #expect(fresh != CloudRecords.newNameKey())
        let id = CloudRecords.recordID(CloudRecords.keyName)
        let record = CloudRecords.fill(
            CKRecord(recordType: CloudRecords.keyType, recordID: id), withNameKey: fresh)
        #expect(CloudRecords.nameKey(from: record) == fresh)
        let short = CloudRecords.fill(
            CKRecord(recordType: CloudRecords.keyType, recordID: id), withNameKey: Data([1, 2, 3]))
        #expect(CloudRecords.nameKey(from: short) == nil)
    }
}

struct SyncStateKeyTests {
    private let ours = Data(repeating: 1, count: 32)
    private let theirs = Data(repeating: 2, count: 32)

    @Test("A device makes a key, offers it until confirmed, and only then sends anything else")
    func steps() {
        var state = SyncState()
        #expect(state.nextKeyStep == .makeThenOffer)
        state.nameKey = ours
        #expect(state.nextKeyStep == .offer)
        state.keyConfirmed = true
        #expect(state.nextKeyStep == .ready)
        // Losing the race is still ready: the winner's key is confirmed by definition.
        state.adopt(nameKey: theirs)
        #expect(state.nextKeyStep == .ready)
    }

    @Test("The server confirming our own key keeps what was pushed")
    func sameKey() {
        var state = SyncState(nameKey: ours, pushedEvents: ["a"])
        let confirmed = state.adopt(nameKey: ours)
        #expect(confirmed)
        #expect(state.keyConfirmed)
        #expect(state.pushedEvents == ["a"])
        let again = state.adopt(nameKey: ours)
        #expect(!again)
    }

    @Test("Losing to another device's key forgets every name made under ours")
    func anotherKeyWins() {
        var state = SyncState(
            nameKey: ours, keyConfirmed: true, pushedEvents: ["a"],
            pushedEntryEdits: ["b": Date(timeIntervalSince1970: 1)],
            systemFields: ["b": Data([1]), CloudRecords.keyName: Data([2])],
            pushedProfile: Profile(industries: ["law"]))
        let changed = state.adopt(nameKey: theirs)
        #expect(changed)
        #expect(state.nameKey == theirs)
        #expect(state.keyConfirmed)
        #expect(state.pushedEvents.isEmpty)
        #expect(state.pushedEntryEdits.isEmpty)
        #expect(state.systemFields.keys.sorted() == [CloudRecords.keyName])
        #expect(state.pushedProfile == nil)
    }
}

struct SyncStateProfileTests {
    private let nurse = Profile(industries: ["healthcare"], role: "nurse", firstLanguage: nil)

    @Test("A profile never sent needs a push; one the server has does not")
    func firstPush() {
        var state = SyncState()
        #expect(state.needsProfilePush(local: nurse))
        state.pushedProfile = nurse
        #expect(!state.needsProfilePush(local: nurse))
    }

    @Test("An edit after the first push is sent again")
    func laterEdit() {
        let state = SyncState(pushedProfile: nurse)
        let edited = Profile(industries: ["healthcare", "law"], role: "nurse", firstLanguage: nil)
        #expect(state.needsProfilePush(local: edited))
    }
}
