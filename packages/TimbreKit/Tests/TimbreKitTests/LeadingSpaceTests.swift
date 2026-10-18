import Testing

@testable import TimbreKit

struct LeadingSpaceTests {

    @Test func aLetterOrFullStopBeforeTheCaretWantsASpace() {
        #expect(LeadingSpace.needed(before: "."))
        #expect(LeadingSpace.needed(before: "e"))
        #expect(LeadingSpace.needed(before: ","))
    }

    @Test func whitespaceBracketsAndQuotesDoNot() {
        #expect(!LeadingSpace.needed(before: " "))
        #expect(!LeadingSpace.needed(before: "\n"))
        #expect(!LeadingSpace.needed(before: "("))
        #expect(!LeadingSpace.needed(before: "“"))
        #expect(!LeadingSpace.needed(before: nil))
    }

    @Test func aSecondDictationIntoTheSameAppFollowsTheFirst() {
        let clock = ContinuousClock()
        let then = clock.now
        #expect(
            LeadingSpace.likelyNeeded(
                lastApp: "Claude", lastText: "Things are looking better.", lastAt: then,
                app: "Claude", now: then + .seconds(4)))
    }

    @Test func aDifferentAppOrALongPauseDoesNot() {
        let clock = ContinuousClock()
        let then = clock.now
        #expect(
            !LeadingSpace.likelyNeeded(
                lastApp: "Claude", lastText: "Things are looking better.", lastAt: then,
                app: "Mail", now: then + .seconds(4)))
        #expect(
            !LeadingSpace.likelyNeeded(
                lastApp: "Claude", lastText: "Things are looking better.", lastAt: then,
                app: "Claude", now: then + .seconds(40)))
        #expect(
            !LeadingSpace.likelyNeeded(
                lastApp: nil, lastText: "Things are looking better.", lastAt: then,
                app: "Claude", now: then))
    }

    @Test func anUnfinishedSentenceIsLeftToTheUser() {
        let clock = ContinuousClock()
        let then = clock.now
        #expect(
            !LeadingSpace.likelyNeeded(
                lastApp: "Claude", lastText: "call the dentist Thursday", lastAt: then,
                app: "Claude", now: then + .seconds(2)))
    }
}
