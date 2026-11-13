import Foundation
import TimbreCore

/// What the sync remembers between launches (ADR-0017): the engine's own
/// state, which events and entry edits the server has, the server's copy
/// of each entry's system fields, and when the last fetch finished. One
/// file beside the Library. Its keys are entry and event ids, which carry
/// the term, so it is as private as the Library itself and is deleted with
/// it; GDR-0031 replaces them with opaque names.
nonisolated public struct SyncState: Codable, Equatable, Sendable {

    /// `CKSyncEngine.State.Serialization`, as data.
    public var engine: Data?
    public var pushedEventIDs: Set<String>
    /// Entry id → the `edited` date the server holds.
    public var pushedEntryEdits: [String: Date]
    /// Entry id or the profile → the server record's system fields.
    public var systemFields: [String: Data]
    /// The profile as the server last had it; nil until the first push or
    /// fetch. A one-shot flag would never send a later edit.
    public var pushedProfile: Profile?
    public var lastFetched: Date?

    public init(
        engine: Data? = nil, pushedEventIDs: Set<String> = [], pushedEntryEdits: [String: Date] = [:],
        systemFields: [String: Data] = [:], pushedProfile: Profile? = nil, lastFetched: Date? = nil
    ) {
        self.engine = engine
        self.pushedEventIDs = pushedEventIDs
        self.pushedEntryEdits = pushedEntryEdits
        self.systemFields = systemFields
        self.pushedProfile = pushedProfile
        self.lastFetched = lastFetched
    }

    public static func load(from url: URL) -> SyncState {
        guard let data = try? Data(contentsOf: url) else { return SyncState() }
        return (try? decoder.decode(SyncState.self, from: data)) ?? SyncState()
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
