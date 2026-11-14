import CloudKit
import CryptoKit
import Foundation
import TimbreCore

/// The Library as CloudKit records (ADR-0017, as amended by ADR-0018).
/// Events are immutable records, only ever added, so two devices merge by
/// union. Entries are replaced whole on edit; the later `edited` wins. The
/// profile is one record. Every field is additive from the first release: a
/// field is never renamed, retyped or removed.
///
/// Nothing the user wrote is readable on the server (GDR-0031). Every field
/// goes through `encryptedValues`, which Advanced Data Protection encrypts
/// end to end; and a record is named by a keyed hash of its id, because the
/// id carries the term and a record name is never encrypted. The key is
/// itself an encrypted value in the zone, so the names are exactly as
/// private as the fields.
nonisolated public enum CloudRecords {

    public static let zoneName = "Library"
    public static let eventType = "Event"
    public static let entryType = "Entry"
    public static let profileType = "Profile"
    public static let profileName = "profile"
    public static let keyType = "Key"
    public static let keyName = "key"

    public static var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    public static func recordID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    // MARK: Names

    /// A fresh 256-bit key for naming records.
    public static func newNameKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    /// The record name for an entry or event id: HMAC-SHA256 under the
    /// zone's key, in hex. The same id gives the same name on every device
    /// holding the key, so a record sent twice is one record; without the
    /// key a name says nothing, not even whether a common word is there.
    public static func name(for id: String, key: Data) -> String {
        HMAC<SHA256>.authenticationCode(for: Data(id.utf8), using: SymmetricKey(data: key))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// The key's own record. Its name is fixed, so the first device to save
    /// it wins and every other device adopts that key.
    public static func fill(_ record: CKRecord, withNameKey key: Data) -> CKRecord {
        record.encryptedValues["key"] = key
        return record
    }

    public static func nameKey(from record: CKRecord) -> Data? {
        guard record.recordType == keyType, let key = record.encryptedValues["key"] as? Data,
            key.count == 32
        else { return nil }
        return key
    }

    // MARK: Events

    public static func record(for event: LibraryEvent, key: Data) -> CKRecord {
        let record = CKRecord(recordType: eventType, recordID: recordID(name(for: event.id, key: key)))
        let values = record.encryptedValues
        values["entry"] = event.entry
        values["kind"] = event.kind.rawValue
        values["date"] = event.date
        values["device"] = event.device.rawValue
        values["app"] = event.app
        values["drill"] = event.drill?.rawValue
        return record
    }

    public static func event(from record: CKRecord) -> LibraryEvent? {
        let values = record.encryptedValues
        guard record.recordType == eventType,
            let entry = values["entry"] as? String,
            let kindRaw = values["kind"] as? String, let kind = LibraryEvent.Kind(rawValue: kindRaw),
            let date = values["date"] as? Date,
            let deviceRaw = values["device"] as? String, let device = Device(rawValue: deviceRaw)
        else { return nil }
        return LibraryEvent(
            entry: entry, kind: kind, date: date, device: device, app: values["app"] as? String,
            drill: (values["drill"] as? String).flatMap(Drill.init(rawValue:)))
    }

    // MARK: Entries

    /// Fills `record` — a fresh one, or the server's copy so its change tag
    /// is kept — with the entry.
    public static func fill(_ record: CKRecord, with entry: LibraryEntry) -> CKRecord {
        let values = record.encryptedValues
        values["kind"] = entry.kind.rawValue
        values["term"] = entry.term
        values["heard"] = entry.heard
        values["meaning"] = entry.meaning
        values["example"] = entry.example
        values["tags"] = entry.tags
        values["sourceDevice"] = entry.source.device.rawValue
        values["sourceDate"] = entry.source.date
        values["sourceHow"] = entry.source.how.rawValue
        values["sourceApp"] = entry.source.app
        values["edited"] = entry.edited
        return record
    }

    public static func record(for entry: LibraryEntry, key: Data) -> CKRecord {
        fill(CKRecord(recordType: entryType, recordID: recordID(name(for: entry.id, key: key))), with: entry)
    }

    public static func entry(from record: CKRecord) -> LibraryEntry? {
        let values = record.encryptedValues
        guard record.recordType == entryType,
            let kindRaw = values["kind"] as? String, let kind = EntryKind(rawValue: kindRaw),
            let term = values["term"] as? String,
            let deviceRaw = values["sourceDevice"] as? String, let device = Device(rawValue: deviceRaw),
            let sourceDate = values["sourceDate"] as? Date,
            let howRaw = values["sourceHow"] as? String, let how = Provenance.How(rawValue: howRaw)
        else { return nil }
        let source = Provenance(
            device: device, date: sourceDate, how: how, app: values["sourceApp"] as? String)
        return LibraryEntry(
            kind: kind, term: term, heard: values["heard"] as? String, meaning: values["meaning"] as? String,
            example: values["example"] as? String, tags: values["tags"] as? [String] ?? [], source: source,
            edited: values["edited"] as? Date ?? sourceDate)
    }

    /// The `edited` date a saved entry record carries.
    public static func edited(of record: CKRecord) -> Date? {
        record.encryptedValues["edited"] as? Date
    }

    // MARK: Profile

    public static func fill(_ record: CKRecord, with profile: Profile) -> CKRecord {
        let values = record.encryptedValues
        values["industries"] = profile.industries
        values["role"] = profile.role
        values["firstLanguage"] = profile.firstLanguage
        return record
    }

    public static func record(for profile: Profile) -> CKRecord {
        fill(CKRecord(recordType: profileType, recordID: recordID(profileName)), with: profile)
    }

    public static func profile(from record: CKRecord) -> Profile? {
        guard record.recordType == profileType else { return nil }
        let values = record.encryptedValues
        return Profile(
            industries: values["industries"] as? [String] ?? [], role: values["role"] as? String,
            firstLanguage: values["firstLanguage"] as? String)
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
