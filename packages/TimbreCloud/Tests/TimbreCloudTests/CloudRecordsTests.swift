import CloudKit
import Foundation
import Testing
import TimbreCore

@testable import TimbreCloud

struct CloudRecordsTests {

    private let source = Provenance(
        device: .iPhone, date: Date(timeIntervalSince1970: 1_700_000_000), how: .dictated, app: "Mail")

    @Test func anEventRoundTrips() {
        let event = LibraryEvent(
            entry: "word:ephemeral", kind: .passed, date: Date(timeIntervalSince1970: 1_700_000_100),
            device: .watch,
            app: nil, drill: .spellIt)
        let record = CloudRecords.record(for: event)
        #expect(record.recordID.recordName == event.id)
        #expect(record.recordID.zoneID.zoneName == "Library")
        #expect(CloudRecords.event(from: record) == event)
    }

    @Test func anEntryRoundTripsWithEveryField() {
        var entry = LibraryEntry(
            kind: .acronym, term: "ADR", meaning: "Architecture Decision Record", example: "We wrote an ADR.",
            tags: ["software"], source: source)!
        entry.edited = Date(timeIntervalSince1970: 1_700_000_500)
        let back = CloudRecords.entry(from: CloudRecords.record(for: entry))
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
        state.pushedEventIDs = ["taught|word:a|1|mac||"]
        state.pushedEntryEdits = ["word:a": Date(timeIntervalSince1970: 1_700_000_000)]
        state.profilePushed = true
        try state.save(to: url)
        #expect(SyncState.load(from: url) == state)
        #expect(SyncState.load(from: directory.appending(path: "missing.json")) == SyncState())
    }
}
