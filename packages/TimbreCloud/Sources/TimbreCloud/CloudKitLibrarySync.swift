import CloudKit
import Foundation
import Observation
import TimbreCore

/// The Library through the user's own iCloud (GDR-0023, decision 1):
/// `CKSyncEngine` over the private database's "Library" zone, events as
/// immutable records, entries by latest edit, the profile as one record
/// (ADR-0017), every field an encrypted value and every record named under
/// the zone's key (ADR-0018). Off until the user turns it on; stopped when
/// they turn it off. The binary makes no request: the engine hands records to the
/// system, and the system's daemon talks to Apple.
@Observable
public final class CloudKitLibrarySync: NSObject {

    public enum Status: Equatable, Sendable {
        case off
        case starting
        case syncing
        case upToDate(Date?)
        case unavailable(String)
    }

    public static let containerIdentifier = "iCloud.dev.hugopretorius.Timbre"

    public private(set) var status: Status = .off

    private let library: Library
    private let stateURL: URL
    private var state: SyncState
    private var engine: CKSyncEngine?
    private var observing = false
    /// Record name → what it names, rebuilt whenever changes are queued.
    private var targets: [String: Target] = [:]
    /// Id → record name, so each hash is computed once per launch.
    private var names: [String: String] = [:]

    private enum Target {
        case entry(String)
        case event(LibraryEvent)
    }

    public init(library: Library, stateURL: URL) {
        self.library = library
        self.stateURL = stateURL
        self.state = SyncState.load(from: stateURL)
        super.init()
    }

    /// Builds the engine and sends everything the server does not have yet.
    public func start() {
        guard engine == nil else { return }
        status = .starting
        let container = CKContainer(identifier: Self.containerIdentifier)
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: state.engine.flatMap {
                try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
            },
            delegate: self)
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: CloudRecords.zoneID))])
        if !observing {
            observing = true
            library.addSaveObserver { [weak self] in self?.queueChanges() }
        }
        queueChanges()
        if !state.keyConfirmed { Task { await self.establishKey() } }
        Task { await self.checkAccount(container) }
    }

    /// Agrees the naming key with the server before anything else is sent
    /// (ADR-0018). A key already in the zone arrives with the fetch and is
    /// adopted; otherwise this device offers one. The key's record name is
    /// fixed, so if two devices offer at once the first save wins and the
    /// other's fails with the winner attached, which it then adopts.
    private func establishKey() async {
        guard let engine else { return }
        try? await engine.fetchChanges()
        guard !state.keyConfirmed else { return }
        if state.nameKey == nil {
            state.nameKey = CloudRecords.newNameKey()
            persist()
        }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CloudRecords.recordID(CloudRecords.keyName))])
        try? await engine.sendChanges()
    }

    /// Stops syncing; what is on the Mac stays on the Mac.
    public func stop() {
        engine = nil
        status = .off
    }

    /// Asks for a fetch and a send now.
    public func syncNow() async {
        guard let engine else { return }
        status = .syncing
        try? await engine.fetchChanges()
        try? await engine.sendChanges()
        status = .upToDate(state.lastFetched)
    }

    // MARK: - What to send

    /// Everything the Library has that the server has not been told of.
    /// Nothing, until the naming key is agreed.
    private func queueChanges() {
        guard let engine, state.keyConfirmed, let key = state.nameKey else { return }
        index(key)
        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for event in library.events {
            let name = name(for: event.id, key)
            if !state.pushedEvents.contains(name) { pending.append(.saveRecord(CloudRecords.recordID(name))) }
        }
        for entry in library.entries {
            let name = name(for: entry.id, key)
            if state.pushedEntryEdits[name].map({ $0 < entry.edited }) ?? true {
                pending.append(.saveRecord(CloudRecords.recordID(name)))
            }
        }
        if state.needsProfilePush(local: library.profile) {
            pending.append(.saveRecord(CloudRecords.recordID(CloudRecords.profileName)))
        }
        if !pending.isEmpty { engine.state.add(pendingRecordZoneChanges: pending) }
    }

    private func name(for id: String, _ key: Data) -> String {
        if let name = names[id] { return name }
        let name = CloudRecords.name(for: id, key: key)
        names[id] = name
        return name
    }

    /// Which entry or event each record name stands for.
    private func index(_ key: Data) {
        var targets: [String: Target] = [:]
        for event in library.events { targets[name(for: event.id, key)] = .event(event) }
        for entry in library.entries { targets[name(for: entry.id, key)] = .entry(entry.id) }
        self.targets = targets
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        let name = recordID.recordName
        let base = state.systemFields[name].flatMap(CloudRecords.record(fromSystemFields:))
        if name == CloudRecords.keyName {
            guard let key = state.nameKey else { return nil }
            return CloudRecords.fill(
                base ?? CKRecord(recordType: CloudRecords.keyType, recordID: recordID), withNameKey: key)
        }
        if name == CloudRecords.profileName {
            return CloudRecords.fill(
                base ?? CKRecord(recordType: CloudRecords.profileType, recordID: recordID),
                with: library.profile)
        }
        guard let key = state.nameKey else { return nil }
        if targets[name] == nil { index(key) }
        switch targets[name] {
        case .entry(let id):
            guard let entry = library.entry(id) else { return nil }
            return CloudRecords.fill(
                base ?? CKRecord(recordType: CloudRecords.entryType, recordID: recordID), with: entry)
        case .event(let event):
            return CloudRecords.record(for: event, key: key)
        case nil:
            return nil
        }
    }

    // MARK: - What arrived

    private func take(_ records: [CKRecord]) {
        var entries: [LibraryEntry] = []
        var events: [LibraryEvent] = []
        var profile: Profile?
        var keyChanged = false
        // The key first: adopting one forgets what was pushed under another.
        for record in records where record.recordType == CloudRecords.keyType {
            guard let key = CloudRecords.nameKey(from: record) else { continue }
            let different = state.nameKey != key
            if state.adopt(nameKey: key) { keyChanged = true }
            if different { names = [:] }
            state.systemFields[CloudRecords.keyName] = CloudRecords.systemFields(of: record)
        }
        for record in records {
            let name = record.recordID.recordName
            switch record.recordType {
            case CloudRecords.eventType:
                if let event = CloudRecords.event(from: record) {
                    events.append(event)
                    state.pushedEvents.insert(name)
                }
            case CloudRecords.entryType:
                if let entry = CloudRecords.entry(from: record) {
                    entries.append(entry)
                    state.pushedEntryEdits[name] = entry.edited
                    state.systemFields[name] = CloudRecords.systemFields(of: record)
                }
            case CloudRecords.profileType:
                profile = CloudRecords.profile(from: record)
                state.systemFields[CloudRecords.profileName] = CloudRecords.systemFields(of: record)
                state.pushedProfile = profile
            default:
                break
            }
        }
        if !entries.isEmpty || !events.isEmpty {
            library.merge(entries: entries, events: events)
        }
        if let profile, profile != library.profile, library.profile == .empty {
            library.profile = profile
        }
        state.lastFetched = Date()
        persist()
        if keyChanged { queueChanges() }
    }

    private func persist() {
        try? state.save(to: stateURL)
    }

    /// The engine hands over its state to keep whenever it changes; it is
    /// handed back at the next launch so nothing is fetched twice.
    private func keep(_ serialization: CKSyncEngine.State.Serialization) {
        state.engine = try? JSONEncoder().encode(serialization)
        persist()
    }

    private func checkAccount(_ container: CKContainer) async {
        do {
            switch try await container.accountStatus() {
            case .available:
                if case .starting = status { status = .upToDate(state.lastFetched) }
            case .noAccount: status = .unavailable("Sign in to iCloud in System Settings to sync.")
            case .restricted: status = .unavailable("iCloud is restricted on this device.")
            case .temporarilyUnavailable: status = .unavailable("iCloud is temporarily unavailable.")
            case .couldNotDetermine: status = .unavailable("Could not reach iCloud.")
            @unknown default: status = .unavailable("iCloud is unavailable.")
            }
        } catch {
            status = .unavailable(error.localizedDescription)
        }
    }
}

extension CloudKitLibrarySync: CKSyncEngineDelegate {

    public nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            let serialization = update.stateSerialization
            await MainActor.run { keep(serialization) }
        case .accountChange(let change):
            if case .signOut = change.changeType {
                await MainActor.run { status = .unavailable("Signed out of iCloud.") }
            }
        case .fetchedRecordZoneChanges(let changes):
            let records = changes.modifications.map(\.record)
            await MainActor.run { take(records) }
        case .sentRecordZoneChanges(let sent):
            let saved = sent.savedRecords
            let conflicts = sent.failedRecordSaves.compactMap { failure -> CKRecord? in
                if case .serverRecordChanged = failure.error.code { return failure.error.serverRecord }
                return nil
            }
            await MainActor.run {
                var keyConfirmed = false
                for record in saved {
                    let name = record.recordID.recordName
                    switch record.recordType {
                    case CloudRecords.eventType: state.pushedEvents.insert(name)
                    case CloudRecords.entryType:
                        state.pushedEntryEdits[name] = CloudRecords.edited(of: record)
                        state.systemFields[name] = CloudRecords.systemFields(of: record)
                    case CloudRecords.keyType:
                        // Ours is the server's key now; everything else may go.
                        state.keyConfirmed = true
                        state.systemFields[name] = CloudRecords.systemFields(of: record)
                        keyConfirmed = true
                    case CloudRecords.profileType:
                        state.pushedProfile = CloudRecords.profile(from: record)
                        state.systemFields[name] = CloudRecords.systemFields(of: record)
                    default: break
                    }
                }
                // The server had a newer copy: take it, merge, and send ours again.
                if !conflicts.isEmpty {
                    take(conflicts)
                    queueChanges()
                }
                persist()
                if keyConfirmed { queueChanges() }
            }
        case .willFetchChanges, .willSendChanges:
            await MainActor.run { status = .syncing }
        case .didFetchChanges, .didSendChanges:
            await MainActor.run { status = .upToDate(state.lastFetched) }
        case .fetchedDatabaseChanges, .sentDatabaseChanges, .willFetchRecordZoneChanges,
            .didFetchRecordZoneChanges:
            break
        @unknown default:
            break
        }
    }

    public nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let scope = context.options.scope
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            await MainActor.run { self.record(for: recordID) }
        }
    }
}
