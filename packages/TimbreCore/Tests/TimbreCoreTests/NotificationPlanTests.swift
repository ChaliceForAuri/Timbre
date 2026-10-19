import Foundation
import Testing

@testable import TimbreCore

struct NotificationPlanTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: hour, minute: minute))!
    }

    @Test func firesTodayWhenTheTimeIsStillAhead() {
        let fire = NotificationPlan.nextFire(hour: 9, minute: 0, after: date(7, 30), calendar: calendar)
        #expect(fire == date(9, 0))
    }

    @Test func firesTomorrowOnceTheTimeHasPassed() {
        let fire = NotificationPlan.nextFire(hour: 9, minute: 0, after: date(9, 0), calendar: calendar)
        #expect(fire == calendar.date(byAdding: .day, value: 1, to: date(9, 0)))
    }
}
