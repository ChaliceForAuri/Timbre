import Testing

@testable import TimbreKit

struct SentenceCapitalizerTests {

    @Test func capitalizesTheStartAndEachSentence() {
        #expect(
            SentenceCapitalizer.capitalized("the deploy went out. it worked! did it? yes.")
                == "The deploy went out. It worked! Did it? Yes.")
    }

    @Test func capitalizesAfterLineBreaksAndBullets() {
        #expect(
            SentenceCapitalizer.capitalized("send it to the team\n\nlet me know")
                == "Send it to the team\n\nLet me know")
        #expect(
            SentenceCapitalizer.capitalized("• first thing\n• second thing")
                == "• First thing\n• Second thing")
    }

    /// The reason this is a rule and not a blanket uppercase.
    @Test func leavesWordsThatCarryTheirOwnCasing() {
        for text in ["iPhone works.", "macOS 26 is out. iOS too.", "eBay sold it"] {
            #expect(SentenceCapitalizer.capitalized(text) == text)
        }
    }

    @Test func anAbbreviationDotDoesNotEndASentence() {
        #expect(
            SentenceCapitalizer.capitalized("try e.g. the tests, i.e. all of them")
                == "Try e.g. the tests, i.e. all of them")
        #expect(SentenceCapitalizer.capitalized("at 9 a.m. we start") == "At 9 a.m. we start")
    }

    @Test func aDecimalOrVersionIsNotASentenceEnd() {
        #expect(SentenceCapitalizer.capitalized("version 0.3.1 shipped") == "Version 0.3.1 shipped")
    }

    @Test func aQuoteOrBracketAtTheStartIsLookedThrough() {
        #expect(
            SentenceCapitalizer.capitalized("\"fine,\" she said. \"go.\"") == "\"Fine,\" she said. \"Go.\"")
        #expect(SentenceCapitalizer.capitalized("(see below.) then") == "(See below.) Then")
    }

    @Test func digitsAtTheStartNeedNoCapital() {
        #expect(SentenceCapitalizer.capitalized("3 things happened") == "3 things happened")
        #expect(SentenceCapitalizer.isCapitalizedAtStart("3 things"))
    }

    @Test func theCheckMirrorsTheRule() {
        #expect(SentenceCapitalizer.isCapitalizedAtStart("The deploy"))
        #expect(SentenceCapitalizer.isCapitalizedAtStart("iPhone works"))
        #expect(SentenceCapitalizer.isCapitalizedAtStart("\"Fine\""))
        #expect(!SentenceCapitalizer.isCapitalizedAtStart("the deploy"))
        #expect(SentenceCapitalizer.isCapitalizedAtStart(""))
    }

    @Test func emptyAndWhitespaceSurvive() {
        #expect(SentenceCapitalizer.capitalized("") == "")
        #expect(SentenceCapitalizer.capitalized("  \n ") == "  \n ")
    }
}
