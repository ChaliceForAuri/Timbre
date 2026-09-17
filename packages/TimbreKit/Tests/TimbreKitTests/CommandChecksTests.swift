import Foundation
import Testing

@testable import TimbreKit

struct CommandChecksTests {

    private func makeCase(_ json: String) throws -> CommandCase {
        try JSONDecoder().decode(CommandCase.self, from: Data(json.utf8))
    }

    @Test func aFailureIsReportedAsDoingNothing() throws {
        let testCase = try makeCase(#"{"id":"x","command":"fix","text":"teh"}"#)
        let failures = CommandChecks.failures(
            for: testCase, result: .init(kind: .failure, text: "model busy"))
        #expect(failures == ["did nothing: model busy"])
    }

    @Test func shortenMustComeBackShorterWithItsFactsIntact() throws {
        let testCase = try makeCase(
            #"{"id":"x","command":"shorten","text":"so basically the release slips to Friday","required":["Friday"]}"#
        )
        let same = CommandChecks.failures(
            for: testCase, result: .init(kind: .replacement, text: "so basically the release slips to Friday")
        )
        #expect(same == ["is not shorter"])

        let lostFact = CommandChecks.failures(
            for: testCase, result: .init(kind: .replacement, text: "It slips."))
        #expect(lostFact == ["lost \"Friday\""])
    }

    @Test func fixMayLeaveCleanTextAlone() throws {
        let testCase = try makeCase(#"{"id":"x","command":"fix","text":"All good.","required":["All good"]}"#)
        #expect(
            CommandChecks.failures(for: testCase, result: .init(kind: .unchanged, text: "All good.")).isEmpty)
    }

    @Test func explainMustExplainRatherThanReplace() throws {
        let testCase = try makeCase(#"{"id":"x","command":"explain","text":"ADR"}"#)
        let failures = CommandChecks.failures(for: testCase, result: .init(kind: .replacement, text: "ADR"))
        #expect(failures == ["explain produced a replacement"])
    }
}

struct CommandChecksStemTests {

    /// Free prose says "architectural" and "decisions"; both are right.
    @Test func aTrailingStarMatchesAWordStem() {
        let answer = "ADR stands for Architectural Decision Record, a log of design decisions."
        #expect(CommandChecks.contains("architect*", in: answer))
        #expect(CommandChecks.contains("decision*", in: answer))
        #expect(!CommandChecks.contains("architecture", in: answer))
        #expect(!CommandChecks.contains("record*", in: "a log of choices"))
    }
}
