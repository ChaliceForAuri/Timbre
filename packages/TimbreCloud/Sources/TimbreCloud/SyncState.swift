import Foundation
import TimbreCore

/// What the sync remembers between launches (ADR-0017): the engine's own
/// state, which events and entry edits the server has, the server's copy
/// of each entry's system fields, and when the last fetch finished. One
/// file beside the Library. Records are known here by their names on the
/// server — keyed hashes, not ids (ADR-0018) — but the file also holds the
/// key that makes them, so it is as private as the Library and is deleted
/// with it.
nonisolated public struct SyncState: Codable, Equatable, Sendable {

    /// The file's shape. A file of another shape — the plain-named one from
    /// before ADR-0018 — is not read: the sync starts again from nothing.
    public static let currentSchema = 2
    public var schema: Int

    /// `CKSyncEngine.State.Serialization`, as data.
    public var engine: Data?
    /// The key record names are made with; nil until one is made or fetched.
    public var nameKey: Data?
    /// Whether `nameKey` is the one the server holds. Until it is, nothing
    /// else is sent: a record named under a key that loses is never found.
    public var keyConfirmed: Bool
    /// The names of the event records the server holds.
    public var pushedEvents: Set<String>
    /// Entry record name → the `edited` date the server holds.
    public var pushedEntryEdits: [String: Date]
    /// Record name → the server record's system fields.
    public var systemFields: [String: Data]
    /// The profile as the server last had it; nil until the first push or
    /// fetch. A one-shot flag would never send a later edit.
    public var pushedProfile: Profile?
    public var lastFetched: Date?

    public init(
        engine: Data? = nil, nameKey: Data? = nil, keyConfirmed: Bool = false,
        pushedEvents: Set<String> = [], pushedEntryEdits: [String: Date] = [:],
        systemFields: [String: Data] = [:], pushedProfile: Profile? = nil, lastFetched: Date? = nil
    ) {
        self.schema = Self.currentSchema
        self.engine = engine
        self.nameKey = nameKey
        self.keyConfirmed = keyConfirmed
        self.pushedEvents = pushedEvents
        self.pushedEntryEdits = pushedEntryEdits
        self.systemFields = systemFields
        self.pushedProfile = pushedProfile
        self.lastFetched = lastFetched
    }

    public static func load(from url: URL) -> SyncState {
        guard let data = try? Data(contentsOf: url) else { return SyncState() }
        guard let state = try? decoder.decode(SyncState.self, from: data),
            state.schema == currentSchema
        else { return SyncState() }
        return state
    }

    /// What a device does next to agree the naming key (ADR-0018, decision
    /// 4), once it has fetched and adopted any key the zone already holds.
    public enum KeyStep: Equatable, Sendable {
        /// The server holds this device's key: everything else may be sent.
        case ready
        /// A key was made earlier and its save has not been confirmed.
        case offer
        /// No key yet: make one, then offer it.
        case makeThenOffer
    }

    public var nextKeyStep: KeyStep {
        if keyConfirmed, nameKey != nil { return .ready }
        return nameKey == nil ? .makeThenOffer : .offer
    }

    /// Takes the server's key. A different key means every name this device
    /// made is wrong, so what it believed the server holds is forgotten and
    /// sent again under the right names. Returns whether anything changed.
    @discardableResult
    public mutating func adopt(nameKey key: Data) -> Bool {
        guard nameKey != key || !keyConfirmed else { return false }
        if nameKey != key {
            pushedEvents = []
            pushedEntryEdits = [:]
            systemFields = systemFields.filter { $0.key == CloudRecords.keyName }
            pushedProfile = nil
        }
        nameKey = key
        keyConfirmed = true
        return true
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Whether the local profile still has to be sent: never sent, or edited
    /// since the server's copy.
    public func needsProfilePush(local: Profile) -> Bool {
        pushedProfile != local
    }
}
