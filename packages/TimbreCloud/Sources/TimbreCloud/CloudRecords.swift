import CloudKit
import Foundation
import TimbreCore

/// The Library as CloudKit records (ADR-0017). Events are immutable
/// records named by their id — only ever added, never changed, so two
/// devices merge by union. Entries are records named by their id and
/// replaced whole on edit; the later `edited` wins. The profile is one
/// record. Every field is additive from the first release: a field is
/// never renamed, retyped or removed.
nonisolated public enum CloudRecords {

    public static let zoneName = "Library"
    public static let eventType = "Event"
    public static let entryType = "Entry"
    public static let profileType = "Profile"
    public static let profileName = "profile"

    public static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: Events

    public static func record(for event: LibraryEvent) -> CKRecord {
        let record = CKRecord(
            recordType: eventType, recordID: CKRecord.ID(recordName: event.id, zoneID: zoneID))
        record["entry"] = event.entry
        record["kind"] = event.kind.rawValue
        record["date"] = event.date
        record["device"] = event.device.rawValue
        record["app"] = event.app
        record["drill"] = event.drill?.rawValue
        return record
    }

    public static func event(from record: CKRecord) -> LibraryEvent? {
        guard record.recordType == eventType,
            let entry = record["entry"] as? String,
            let kindRaw = record["kind"] as? String, let kind = LibraryEvent.Kind(rawValue: kindRaw),
            let date = record["date"] as? Date,
            let deviceRaw = record["device"] as? String, let device = Device(rawValue: deviceRaw)
        else { return nil }
        return LibraryEvent(
            entry: entry, kind: kind, date: date, device: device, app: record["app"] as? String,
            drill: (record["drill"] as? String).flatMap(Drill.init(rawValue:)))
    }

    // MARK: Entries

    /// Fills `record` — a fresh one, or the server's copy so its change tag
    /// is kept — with the entry.
    public static func fill(_ record: CKRecord, with entry: LibraryEntry) -> CKRecord {
        record["kind"] = entry.kind.rawValue
        record["term"] = entry.term
        record["heard"] = entry.heard
        record["meaning"] = entry.meaning
        record["example"] = entry.example
        record["tags"] = entry.tags
        record["sourceDevice"] = entry.source.device.rawValue
        record["sourceDate"] = entry.source.date
        record["sourceHow"] = entry.source.how.rawValue
        record["sourceApp"] = entry.source.app
        record["edited"] = entry.edited
        return record
    }

    public static func record(for entry: LibraryEntry) -> CKRecord {
        fill(
            CKRecord(recordType: entryType, recordID: CKRecord.ID(recordName: entry.id, zoneID: zoneID)),
            with: entry)
    }

    public static func entry(from record: CKRecord) -> LibraryEntry? {
        guard record.recordType == entryType,
            let kindRaw = record["kind"] as? String, let kind = EntryKind(rawValue: kindRaw),
            let term = record["term"] as? String,
            let deviceRaw = record["sourceDevice"] as? String, let device = Device(rawValue: deviceRaw),
            let sourceDate = record["sourceDate"] as? Date,
            let howRaw = record["sourceHow"] as? String, let how = Provenance.How(rawValue: howRaw)
        else { return nil }
        let source = Provenance(
            device: device, date: sourceDate, how: how, app: record["sourceApp"] as? String)
        return LibraryEntry(
            kind: kind, term: term, heard: record["heard"] as? String, meaning: record["meaning"] as? String,
            example: record["example"] as? String, tags: record["tags"] as? [String] ?? [], source: source,
            edited: record["edited"] as? Date ?? sourceDate)
    }

    // MARK: Profile

    public static func fill(_ record: CKRecord, with profile: Profile) -> CKRecord {
        record["industries"] = profile.industries
        record["role"] = profile.role
        record["firstLanguage"] = profile.firstLanguage
        return record
    }

    public static func record(for profile: Profile) -> CKRecord {
        fill(
            CKRecord(recordType: profileType, recordID: CKRecord.ID(recordName: profileName, zoneID: zoneID)),
            with: profile)
    }

    public static func profile(from record: CKRecord) -> Profile? {
        guard record.recordType == profileType else { return nil }
        return Profile(
            industries: record["industries"] as? [String] ?? [], role: record["role"] as? String,
            firstLanguage: record["firstLanguage"] as? String)
    }

    /// The server's system fields, kept so an edit saves over the server's
    /// copy rather than fighting it.
    public static func systemFields(of record: CKRecord) -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    public static func record(fromSystemFields data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        return CKRecord(coder: unarchiver)
    }
}
