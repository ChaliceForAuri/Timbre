import Foundation
import FoundationModels
import TimbreCore

/// The model's half of Say it and Explain it (GDR-0023, decision 5),
/// where the model is. Each asks one yes-or-no question with one line of
/// reason, decodes greedily, and is believed only in the shape the
/// guardrail allows. Everything checkable without the model was checked
/// before this is called.
public final class ModelDrillJudge: DrillJudge, Sendable {

    @Generable
    nonisolated struct Verdict {
        @Guide(description: "true when the word is used in its given meaning; false otherwise.")
        var passed: Bool
        @Guide(description: "One short sentence saying why, addressed to the learner. Under twenty words.")
        var reason: String
    }

    public init() {}

    private static let sayItInstructions = """
        You judge whether a learner used a word correctly in a sentence they said aloud.

        Rules:
        1. Decide only whether the word is used in the meaning given. Grammar, style and \
        punctuation do not matter; the sentence was spoken.
        2. A sentence that uses the word as if it meant something else fails.
        3. Say why in one short, kind sentence addressed to the learner, under twenty words. \
        Never quote the whole sentence back.
        """

    private static let explainItInstructions = """
        You judge whether a learner's spoken explanation of a word captures its meaning.

        Rules:
        1. Decide only whether the explanation means the same as the meaning given, in \
        other words. Partial but correct counts; wrong or empty does not.
        2. Say why in one short, kind sentence addressed to the learner, under twenty words.
        """

    public func judgeSayIt(term: String, meaning: String?, sentence: String) async -> DrillVerdict? {
        var lines = ["Word: \(term)"]
        if let meaning, !meaning.isEmpty { lines.append("Meaning: \(meaning)") }
        lines.append("The learner said: \(sentence)")
        lines.append("Was the word used in its meaning?")
        return await ask(lines.joined(separator: "\n"), instructions: Self.sayItInstructions)
    }

    public func judgeExplainIt(term: String, meaning: String, explanation: String) async -> DrillVerdict? {
        let prompt = """
            Word: \(term)
            Meaning: \(meaning)
            The learner explained it as: \(explanation)
            Does the explanation capture the meaning?
            """
        return await ask(prompt, instructions: Self.explainItInstructions)
    }

    private func ask(_ prompt: String, instructions: String) async -> DrillVerdict? {
        guard OnDeviceModel.availability.isReady else { return nil }
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: prompt,
                generating: Verdict.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy)
            )
            let verdict = DrillVerdict(
                passed: response.content.passed,
                reason: response.content.reason.trimmingCharacters(in: .whitespacesAndNewlines))
            return SayItGuardrail.accepts(verdict) ? verdict : nil
        } catch {
            return nil
        }
    }
}
