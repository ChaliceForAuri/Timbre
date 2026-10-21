import CloudKit
import Foundation
import Observation
import TimbreCore

/// The Library through the user's own iCloud (GDR-0023, decision 1):
/// `CKSyncEngine` over the private database's "Library" zone, events as
/// immutable records, entries by latest edit, the profile as one record
/// (ADR-0017). Off until the user turns it on; stopped when they turn it
/// off. The binary makes no request: the engine hands records to the
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
        Task { await self.checkAccount(container) }
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
    private func queueChanges() {
        guard let engine else { return }
        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        for event in library.events where !state.pushedEventIDs.contains(event.id) {
            pending.append(.saveRecord(CKRecord.ID(recordName: event.id, zoneID: CloudRecords.zoneID)))
        }
        for entry in library.entries where state.pushedEntryEdits[entry.id].map({ $0 < entry.edited }) ?? true
        {
            pending.append(.saveRecord(CKRecord.ID(recordName: entry.id, zoneID: CloudRecords.zoneID)))
        }
        if !state.profilePushed {
            pending.append(
                .saveRecord(CKRecord.ID(recordName: CloudRecords.profileName, zoneID: CloudRecords.zoneID)))
        }
        if !pending.isEmpty { engine.state.add(pendingRecordZoneChanges: pending) }
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        let name = recordID.recordName
        if name == CloudRecords.profileName {
            let base =
                state.systemFields[name].flatMap(CloudRecords.record(fromSystemFields:))
                ?? CKRecord(recordType: CloudRecords.profileType, recordID: recordID)
            return CloudRecords.fill(base, with: library.profile)
        }
        if let entry = library.entry(name) {
            let base =
                state.systemFields[name].flatMap(CloudRecords.record(fromSystemFields:))
                ?? CKRecord(recordType: CloudRecords.entryType, recordID: recordID)
            return CloudRecords.fill(base, with: entry)
        }
        if let event = library.events.first(where: { $0.id == name }) {
            return CloudRecords.record(for: event)
        }
        return nil
    }

    // MARK: - What arrived

    private func take(_ records: [CKRecord]) {
        var entries: [LibraryEntry] = []
        var events: [LibraryEvent] = []
        var profile: Profile?
        for record in records {
            switch record.recordType {
            case CloudRecords.eventType:
                if let event = CloudRecords.event(from: record) {
                    events.append(event)
                    state.pushedEventIDs.insert(event.id)
                }
            case CloudRecords.entryType:
                if let entry = CloudRecords.entry(from: record) {
                    entries.append(entry)
                    state.pushedEntryEdits[entry.id] = entry.edited
                    state.systemFields[entry.id] = CloudRecords.systemFields(of: record)
                }
            case CloudRecords.profileType:
                profile = CloudRecords.profile(from: record)
                state.systemFields[CloudRecords.profileName] = CloudRecords.systemFields(of: record)
                state.profilePushed = true
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
                for record in saved {
                    let name = record.recordID.recordName
                    switch record.recordType {
                    case CloudRecords.eventType: state.pushedEventIDs.insert(name)
                    case CloudRecords.entryType:
                        state.pushedEntryEdits[name] = record["edited"] as? Date
                        state.systemFields[name] = CloudRecords.systemFields(of: record)
                    case CloudRecords.profileType:
                        state.profilePushed = true
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
