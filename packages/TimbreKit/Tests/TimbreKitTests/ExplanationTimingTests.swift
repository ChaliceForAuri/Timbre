import Testing

@testable import TimbreKit

struct ExplanationTimingTests {

    @Test func staysLongEnoughToReadButNeverInTheWay() {
        let short = ExplanationTiming.displayDuration(for: "Application Programming Interface.")
        let medium = ExplanationTiming.displayDuration(for: String(repeating: "word ", count: 40))
        let long = ExplanationTiming.displayDuration(for: String(repeating: "word ", count: 400))

        #expect(short == .seconds(6))
        #expect(medium > short && medium < long)
        #expect(long == .seconds(25))
    }
}
