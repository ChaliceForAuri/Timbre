import Foundation
import Testing
import TimbreCore

@testable import TimbreRelay

struct PendingTodosTests {

    private let todo = Todo(
        title: "Call the dentist", due: Date(timeIntervalSince1970: 1_700_000_000), hasTime: true)

    @Test func enqueueFiledAndPersist() throws {
        let directory = URL(filePath: NSTemporaryDirectory()).appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "pending.json")

        var queue = PendingTodos()
        let item = queue.enqueue(todo, at: Date(timeIntervalSince1970: 1_700_000_100))
        try queue.save(to: url)
        #expect(PendingTodos.load(from: url) == queue)

        let firstTime = queue.filed(item.id)
        let secondTime = queue.filed(item.id)
        #expect(firstTime)
        #expect(!secondTime)
        #expect(queue.isEmpty)
        #expect(PendingTodos.load(from: directory.appending(path: "missing.json")).isEmpty)
    }

    @Test func messagesRoundTrip() {
        let item = PendingTodo(todo: todo)
        let request = RelayMessage.request(item)
        let parsed = RelayMessage.parseRequest(request)
        #expect(parsed?.id == item.id)
        #expect(parsed?.todo == todo)
        #expect(RelayMessage.parseRequest(["todo": "not data"]) == nil)

        let reply = RelayMessage.reply(filed: item.id, list: "Timbre")
        let answer = RelayMessage.parseReply(reply)
        #expect(answer?.id == item.id)
        #expect(answer?.list == "Timbre")
        #expect(RelayMessage.parseReply([:]) == nil)
    }
}
