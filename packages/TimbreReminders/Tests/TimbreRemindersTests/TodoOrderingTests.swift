import Foundation
import Testing
import TimbreCore

@testable import TimbreReminders

struct TodoOrderingTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func soonestFirstUndatedLast() {
        let todos = [
            Todo(title: "Zebra", due: nil, hasTime: false),
            Todo(title: "Later", due: now.addingTimeInterval(7200), hasTime: true),
            Todo(title: "Apple", due: nil, hasTime: false),
            Todo(title: "Soon", due: now, hasTime: true),
        ]
        #expect(TodoOrdering.soonestFirst(todos).map(\.title) == ["Soon", "Later", "Apple", "Zebra"])
    }

    @Test func equalDatesFallBackToTheTitle() {
        let todos = [Todo(title: "B", due: now, hasTime: false), Todo(title: "A", due: now, hasTime: false)]
        #expect(TodoOrdering.soonestFirst(todos).map(\.title) == ["A", "B"])
    }
}
