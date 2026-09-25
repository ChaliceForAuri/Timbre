import Foundation
import Testing

@testable import TimbreKit

struct TodoParserTests {

    private let calendar = Calendar.current

    @Test func aDayNameBecomesADateOnlyDueDate() {
        let todo = TodoParser.parse("call the dentist Thursday")
        #expect(todo.title == "Call the dentist")
        #expect(!todo.hasTime)
        let due = try! #require(todo.due)
        #expect(calendar.component(.weekday, from: due) == 5)
        #expect(due == calendar.startOfDay(for: due))
    }

    @Test func aTimeOfDayKeepsTheTimeAndDropsItsPreposition() {
        let todo = TodoParser.parse("buy milk tomorrow at 3pm")
        #expect(todo.title == "Buy milk")
        #expect(todo.hasTime)
        let due = try! #require(todo.due)
        #expect(calendar.component(.hour, from: due) == 15)
        #expect(calendar.isDate(due, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: Date())!))
    }

    @Test func noDateIsFine() {
        let todo = TodoParser.parse("pay the invoice")
        #expect(todo == Todo(title: "Pay the invoice", due: nil, hasTime: false))
    }

    @Test(arguments: [
        "remind me to renew the passport", "Remember to renew the passport", "add a todo renew the passport",
        "note to self: renew the passport", "I need to renew the passport",
    ])
    func openersAreStripped(spoken: String) {
        #expect(TodoParser.parse(spoken).title == "Renew the passport")
    }

    @Test func aPrepositionBeforeTheDateGoesWithIt() {
        #expect(TodoParser.parse("book flights on 14 October").title == "Book flights")
        #expect(TodoParser.parse("send the invoice by Friday").title == "Send the invoice")
    }

    /// A to-do that is only a date is still a to-do, not an empty title.
    @Test func neverAnEmptyTitle() {
        #expect(!TodoParser.parse("tomorrow").title.isEmpty)
    }
}

struct TodoPhrasingTests {

    private var thursdayNoon: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day! += 2
        components.hour = 15
        return Calendar.current.date(from: components)!
    }

    @Test func confirmationsNameTheListAndTheDay() {
        let dated = Todo(
            title: "Call the dentist", due: Calendar.current.startOfDay(for: thursdayNoon), hasTime: false)
        #expect(
            TodoPhrasing.confirmation(dated, list: "Timbre").hasPrefix("Added to Timbre: Call the dentist · ")
        )
        let undated = Todo(title: "Pay the invoice", due: nil, hasTime: false)
        #expect(TodoPhrasing.confirmation(undated, list: "Timbre") == "Added to Timbre: Pay the invoice")
    }

    @Test func todayAndTomorrowAreSaidAsSuch() {
        let now = Date()
        #expect(TodoPhrasing.when(now, hasTime: false, now: now) == "today")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        #expect(TodoPhrasing.when(tomorrow, hasTime: false, now: now) == "tomorrow")
    }

    @Test func theSpokenListCountsAndOrders() {
        #expect(TodoPhrasing.spokenList([], list: "Timbre") == "Your Timbre list is empty.")
        let one = TodoPhrasing.spokenList(
            [Todo(title: "Pay the invoice", due: nil, hasTime: false)], list: "Timbre")
        #expect(one == "You have one to-do. Pay the invoice.")
    }
}
