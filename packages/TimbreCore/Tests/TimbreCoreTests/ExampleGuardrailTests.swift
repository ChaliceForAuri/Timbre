import Testing

@testable import TimbreCore

struct ExampleGuardrailTests {

    @Test func aPlainSentenceUsingTheWordPasses() {
        let sentence = "The cache is ephemeral, so a restart clears it and nothing is lost."
        #expect(ExampleGuardrail.failures(in: sentence, for: "ephemeral").isEmpty)
        #expect(ExampleGuardrail.accepted("  \(sentence)  ", for: "ephemeral") == sentence)
    }

    @Test func theWordMustAppearWhole() {
        #expect(
            ExampleGuardrail.failures(in: "Fame fades fast and nobody remembers the name.", for: "ephemeral")
                == [.missingTerm])
        #expect(
            ExampleGuardrail.failures(
                in: "This is ephemerally stored and gone in a flash now.", for: "ephemeral")
                == [.missingTerm])
    }

    @Test func lengthIsBounded() {
        #expect(ExampleGuardrail.failures(in: "Ephemeral things fade.", for: "ephemeral") == [.tooShort])
        let long = Array(repeating: "very", count: 40).joined(separator: " ") + " ephemeral."
        #expect(ExampleGuardrail.failures(in: long, for: "ephemeral") == [.tooLong])
    }

    @Test func atMostTwoSentences() {
        let three = "The cache is ephemeral. It clears on restart. Nothing is lost at all."
        #expect(ExampleGuardrail.failures(in: three, for: "ephemeral") == [.tooManySentences])
    }

    @Test func answersAreNotExamples() {
        #expect(
            ExampleGuardrail.failures(
                in: "\"The cache is ephemeral, so a restart clears it entirely.\"", for: "ephemeral")
                == [.quoted])
        #expect(
            ExampleGuardrail.failures(
                in: "Here is a sentence: the cache is ephemeral and clears on restart.", for: "ephemeral")
                == [.prefaced])
        #expect(
            ExampleGuardrail.failures(
                in: "The [thing] is ephemeral and clears on every restart.", for: "ephemeral")
                == [.placeholder])
    }

    @Test func emptyIsTheOnlyFailureReported() {
        #expect(ExampleGuardrail.failures(in: "   ", for: "ephemeral") == [.empty])
        #expect(ExampleGuardrail.accepted("", for: "ephemeral") == nil)
    }
}
