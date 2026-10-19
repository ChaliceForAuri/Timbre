import Foundation
import Observation
import TimbreCore
import WatchConnectivity

/// The two ends of one conversation (GDR-0029). On the Watch, `send` queues
/// a to-do and hands it over; the phone's reply clears it. On the iPhone,
/// `onTodo` files what arrives and replies. `transferUserInfo` is queued by
/// the system and delivered when the other device is reachable, launching
/// the iPhone app in the background if need be — so a to-do said in a
/// tunnel is not lost, only late.
@Observable
public final class Relay: NSObject {

    public private(set) var pending: PendingTodos
    public private(set) var isActivated = false

    /// iPhone: files the to-do, returns the list it went to.
    public var onTodo: (@MainActor (Todo) async throws -> String)?
    /// Watch: the phone filed one.
    public var onFiled: (@MainActor (PendingTodo, String) -> Void)?

    private let queueURL: URL

    public init(queueURL: URL) {
        self.queueURL = queueURL
        self.pending = PendingTodos.load(from: queueURL)
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Watch: queue it and hand it to the phone.
    @discardableResult
    public func send(_ todo: Todo) -> PendingTodo {
        let item = pending.enqueue(todo)
        try? pending.save(to: queueURL)
        if WCSession.isSupported() {
            WCSession.default.transferUserInfo(RelayMessage.request(item))
        }
        return item
    }

    /// Watch: hand over anything still waiting, after a relaunch.
    public func resend() {
        guard WCSession.isSupported() else { return }
        let inFlight = Set(
            WCSession.default.outstandingUserInfoTransfers.compactMap {
                $0.userInfo[RelayMessage.idKey] as? String
            })
        for item in pending.items where !inFlight.contains(item.id.uuidString) {
            WCSession.default.transferUserInfo(RelayMessage.request(item))
        }
    }

    /// Parsed before it crosses onto the main actor: the raw dictionary is not
    /// Sendable, a to-do and an id are.
    private func received(request: (id: UUID, todo: Todo)?, reply: (id: UUID, list: String)?) async {
        if let request, let onTodo {
            guard let list = try? await onTodo(request.todo) else { return }
            WCSession.default.transferUserInfo(RelayMessage.reply(filed: request.id, list: list))
        } else if let reply, let item = pending.items.first(where: { $0.id == reply.id }) {
            pending.filed(reply.id)
            try? pending.save(to: queueURL)
            onFiled?(item, reply.list)
        }
    }
}

extension Relay: WCSessionDelegate {

    public nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isActivated = activationState == .activated
            #if os(watchOS)
                resend()
            #endif
        }
    }

    public nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let request = RelayMessage.parseRequest(userInfo)
        let reply = RelayMessage.parseReply(userInfo)
        Task { @MainActor in await received(request: request, reply: reply) }
    }

    #if os(iOS)
        public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

        public nonisolated func sessionDidDeactivate(_ session: WCSession) {
            session.activate()
        }
    #endif
}
