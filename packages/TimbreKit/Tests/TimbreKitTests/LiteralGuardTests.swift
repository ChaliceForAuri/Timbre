import Testing

@testable import TimbreKit

struct LiteralGuardTests {

    @Test func masksSlackMentionsAndChannels() {
        let masked = LiteralGuard.mask("cc @here and <@U01AB2CD3EF> in #eng-releases, thanks @Eric.Greene")
        #expect(masked.literals == ["@here", "<@U01AB2CD3EF>", "#eng-releases", "@Eric.Greene"])
        #expect(masked.text == "cc LIT1 and LIT2 in LIT3, thanks LIT4")
    }

    @Test func masksDatesTimesUnitsAndAbbreviations() {
        let masked = LiteralGuard.mask("Due 14/08/2026 at 9:30 am, e.g. after 30s, v0.3.1 uses 2.5 GB")
        #expect(masked.literals == ["14/08/2026", "9:30 am", "e.g.", "30s", "v0.3.1", "2.5 GB"])
    }

    /// The units pattern must not eat ordinary words.
    @Test func plainNumbersAndPrepositionsAreNotLiterals() {
        #expect(LiteralGuard.mask("3 in the morning, 2 of them, 5 days").literals.isEmpty)
        #expect(LiteralGuard.mask("issue #27 and #1").literals.isEmpty)
    }

    @Test func masksWebAndCode() {
        let masked = LiteralGuard.mask(
            "see https://x.dev/a?b=1 or mail hi@hugopretorius.dev; run `swift test` in ~/Spoke/web")
        #expect(
            masked.literals == ["https://x.dev/a?b=1", "hi@hugopretorius.dev", "`swift test`", "~/Spoke/web"])
    }

    @Test func restoresEveryLiteralInPlace() {
        let text = "ping @here about 14/08/2026 at 9:30 am"
        let masked = LiteralGuard.mask(text)
        #expect(LiteralGuard.restore(masked.text, from: masked, requireAll: true) == text)
        #expect(
            LiteralGuard.restore("Ping lit1 about LIT2 at LIT3.", from: masked, requireAll: true)
                == "Ping @here about 14/08/2026 at 9:30 am.")
    }

    /// Fix must give everything back; shorten may drop one.
    @Test func aDroppedPlaceholderFailsFixButNotShorten() {
        let masked = LiteralGuard.mask("ping @here about 14/08/2026")
        #expect(LiteralGuard.restore("ping LIT1", from: masked, requireAll: true) == nil)
        #expect(LiteralGuard.restore("ping LIT1", from: masked, requireAll: false) == "ping @here")
    }

    @Test func anInventedPlaceholderIsRefused() {
        let masked = LiteralGuard.mask("ping @here")
        #expect(LiteralGuard.restore("ping LIT2", from: masked, requireAll: false) == nil)
    }

    @Test func noLiteralsMeansNoInstruction() {
        #expect(LiteralGuard.instruction(for: LiteralGuard.mask("just words")) == nil)
        #expect(LiteralGuard.instruction(for: LiteralGuard.mask("at 9:30 am")) != nil)
    }
}

struct CaseKeeperTests {

    @Test func aFixedWordKeepsItsCase() {
        #expect(CaseKeeper.keepingCase(of: "teh", in: "The") == "the")
        #expect(CaseKeeper.keepingCase(of: "teh build", in: "The build") == "the build")
    }

    @Test func aSentenceIsNotAFragment() {
        #expect(
            CaseKeeper.keepingCase(of: "teh build is green.", in: "The build is green.")
                == "The build is green.")
        #expect(!CaseKeeper.isFragment("lets ship on friday not thursday, its safer"))
    }

    @Test func aCorrectionToACasedWordStands() {
        #expect(CaseKeeper.keepingCase(of: "iphone", in: "iPhone") == "iPhone")
        #expect(CaseKeeper.keepingCase(of: "github", in: "GitHub") == "GitHub")
    }

    @Test func anAlreadyCapitalisedSelectionIsLeftAlone() {
        #expect(CaseKeeper.keepingCase(of: "Teh", in: "The") == "The")
    }
}
