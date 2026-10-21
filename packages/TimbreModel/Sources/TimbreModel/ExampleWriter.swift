import Foundation
import FoundationModels
import TimbreCore

/// Writes the card's example sentence (GDR-0027, property 4): one sentence
/// that uses today's word the way the reader's colleagues would. The model
/// never writes a fact; this is the one line it writes, and the card labels
/// it as the model's. Greedy, guarded by `ExampleGuardrail`, measured by
/// `timbre-eval --examples` — the discipline of every other prompt here
/// (ADR-0009, ADR-0011).
public final class ExampleWriter {

    public init() {}

    @Generable
    nonisolated struct Example {
        @Guide(
            description:
                "One or two plain sentences that use the word naturally. No quotation marks, no preamble, no definition."
        )
        var sentence: String
    }

    static var availability: (isReady: Bool, reason: String?) { OnDeviceModel.availability }

    private static let instructions = """
        You write one example sentence for a word, the way a colleague would use it in an \
        ordinary message at work.

        Rules, in priority order:
        1. Use the exact word given, once, in the meaning given.
        2. One sentence, two at most, between eight and thirty words.
        3. Plain prose. No quotation marks around it, no "Example:", no definition of the \
        word, no commentary before or after.
        4. If the reader's field is given, set the sentence in that field without naming it.
        5. Never state a fact about a real person, company or event.
        """

    /// The model's sentence, unchecked. The harness reads this to report
    /// which rule a draft broke; the card never sees it.
    public func draft(for term: String, meaning: String?, industry: String?) async -> String? {
        guard Self.availability.isReady else { return nil }
        let prompt = Self.makePrompt(term: term, meaning: meaning, industry: industry)
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: prompt,
                generating: Example.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy)
            )
            return response.content.sentence
        } catch {
            return nil
        }
    }

    /// A sentence that passed the guardrail, or nil: the card shows no
    /// example rather than a bad one.
    public func write(for term: String, meaning: String?, industry: String?) async -> String? {
        guard let draft = await draft(for: term, meaning: meaning, industry: industry) else { return nil }
        return ExampleGuardrail.accepted(draft, for: term)
    }

    /// Prompt assembly, separated from the model call so it is testable.
    public nonisolated static func makePrompt(term: String, meaning: String?, industry: String?) -> String {
        var lines = ["Word: \(term)"]
        if let meaning, !meaning.isEmpty { lines.append("Meaning: \(meaning)") }
        if let industry, !industry.isEmpty { lines.append("The reader works in \(industry).") }
        lines.append("Write the sentence.")
        return lines.joined(separator: "\n")
    }
}
