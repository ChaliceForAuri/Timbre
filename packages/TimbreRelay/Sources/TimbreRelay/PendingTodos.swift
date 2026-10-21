import Foundation
import TimbreCore

/// A to-do said on the wrist that the iPhone has not yet filed (GDR-0029).
nonisolated public struct PendingTodo: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let todo: Todo
    public let captured: Date

    public init(id: UUID = UUID(), todo: Todo, captured: Date = Date()) {
        self.id = id
        self.todo = todo
        self.captured = captured
    }
}

/// The queue on the Watch: what has been said and not yet confirmed filed.
/// Persisted, so a to-do said in a tunnel survives the app being dropped
/// from memory before the phone is back. Pure, so it is tested without a
/// session.
nonisolated public struct PendingTodos: Codable, Equatable, Sendable {

    public private(set) var items: [PendingTodo]

    public init(items: [PendingTodo] = []) {
        self.items = items
    }

    public mutating func enqueue(_ todo: Todo, at date: Date = Date()) -> PendingTodo {
        let pending = PendingTodo(todo: todo, captured: date)
        items.append(pending)
        return pending
    }

    /// The phone filed it; returns whether it was still waiting.
    @discardableResult
    public mutating func filed(_ id: UUID) -> Bool {
        let before = items.count
        items.removeAll { $0.id == id }
        return items.count < before
    }

    public var isEmpty: Bool { items.isEmpty }

    public static func load(from url: URL) -> PendingTodos {
        guard let data = try? Data(contentsOf: url) else { return PendingTodos() }
        return (try? Self.decoder.decode(PendingTodos.self, from: data)) ?? PendingTodos()
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
}

/// What crosses WatchConnectivity, as the dictionary it wants: the to-do as
/// JSON under one key, the id under another; the answer is the id and the
/// list it went to.
nonisolated public enum RelayMessage {

    public static let todoKey = "todo"
    public static let idKey = "id"
    public static let filedKey = "filed"
    public static let listKey = "list"

    public static func request(_ pending: PendingTodo) -> [String: Any] {
        let data = (try? JSONEncoder().encode(pending.todo)) ?? Data()
        return [todoKey: data, idKey: pending.id.uuidString]
    }

    public static func parseRequest(_ userInfo: [String: Any]) -> (id: UUID, todo: Todo)? {
        guard let data = userInfo[todoKey] as? Data, let raw = userInfo[idKey] as? String,
            let id = UUID(uuidString: raw),
            let todo = try? JSONDecoder().decode(Todo.self, from: data)
        else { return nil }
        return (id, todo)
    }

    public static func reply(filed id: UUID, list: String) -> [String: Any] {
        [filedKey: id.uuidString, listKey: list]
    }

    public static func parseReply(_ userInfo: [String: Any]) -> (id: UUID, list: String)? {
        guard let raw = userInfo[filedKey] as? String, let id = UUID(uuidString: raw) else { return nil }
        return (id, userInfo[listKey] as? String ?? "Reminders")
    }
}
