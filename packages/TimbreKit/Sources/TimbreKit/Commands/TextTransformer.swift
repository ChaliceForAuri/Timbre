import Foundation
import FoundationModels

/// Runs a command on selected text with the on-device model (GDR-0012).
///
/// The contract is the inverse of the polisher's. Dictation must always paste
/// *something*; a command must never damage what is already there. Every
/// failure — model unavailable, an answer the guardrail rejects, a thrown
/// error — comes back as `.failure`, and the caller leaves the selection
/// untouched.
final class TextTransformer {

    @Generable
    nonisolated struct Output {
        @Guide(description: "The result only. Never add commentary, quotes, or a preamble.")
        var text: String
    }

    nonisolated enum Outcome: Equatable, Sendable {
        /// Paste this over the selection.
        case replacement(String)
        /// Show this; the selection is not touched. The source is shown with
        /// it, because a taught definition and a model's guess deserve
        /// different amounts of trust.
        case explanation(String, source: ExplanationSource)
        /// Nothing needed doing. A message for the pill.
        case unchanged(String)
        /// Nothing was done. A message for the pill.
        case failure(String)
    }

    nonisolated enum ExplanationSource: Equatable, Sendable {
        /// The user's own definition, word for word.
        case dictionary
        /// The on-device model, possibly grounded in taught definitions.
        case model

        var caption: String {
            switch self {
            case .dictionary: "From your dictionary"
            case .model: "On-device model · may be wrong"
            }
        }
    }

    func run(
        _ command: VoiceCommand,
        on selection: String,
        corrections: [Correction] = [],
        acronyms: [Acronym] = []
    ) async -> Outcome {
        await runDetailed(command, on: selection, corrections: corrections, acronyms: acronyms).outcome
    }

    /// `run`, plus why a failure failed. The user is told only that their
    /// text is unchanged; the evaluation harness needs to know whether the
    /// guardrail refused an answer or the model threw.
    func runDetailed(
        _ command: VoiceCommand,
        on selection: String,
        corrections: [Correction] = [],
        acronyms: [Acronym] = []
    ) async -> (outcome: Outcome, diagnostic: String?) {
        let frame = SelectionFrame(selection)
        guard !frame.core.isEmpty else { return (.failure("Select some text first."), nil) }

        // The user's own definition answers first, with no model involved.
        // Measured, the model expands "ADR" as "Architecture Design Review"
        // three runs in five and never admits doubt; a taught term cannot be
        // wrong, needs no network of knowledge, and is instant.
        if command == .explain, let taught = AcronymTable.exactAnswer(for: frame.core, from: acronyms) {
            return (.explanation(taught, source: .dictionary), nil)
        }

        guard frame.core.count <= TransformGuardrail.maximumSelectionLength else {
            return (.failure("That selection is too long for the on-device model."), nil)
        }

        // Fix starts with everything that has a right answer: what the user
        // has taught (GDR-0011), then accidentally doubled words. If the model
        // then fails, that much is still worth keeping.
        let source =
            command == .fix
            ? DoubledWords.collapsed(CorrectionTable.applied(corrections, to: frame.core))
            : frame.core
        let mechanicalFix: Outcome? = source != frame.core ? .replacement(frame.wrapping(source)) : nil

        let availability = TextPolisher.availability
        guard availability.isReady else {
            let reason = availability.reason ?? "The on-device model is unavailable right now."
            return (mechanicalFix ?? .failure(reason), "model unavailable")
        }

        do {
            let result = try await generate(command, from: source, acronyms: acronyms)

            // Greedy decoding's strongest pull is to copy its input. When a
            // shortening comes back the same length, the honest report is
            // that there was nothing to cut, not that something went wrong.
            if command == .shorten, TransformGuardrail.isNoReduction(result, original: source) {
                return (
                    .unchanged("That's already tight."), "no reduction: \(result.count) of \(source.count)"
                )
            }

            guard TransformGuardrail.accepts(result, for: command, original: source) else {
                return (
                    mechanicalFix ?? .failure(Self.refusal(for: command)),
                    "guardrail refused \(result.count) chars against \(source.count): \(result.prefix(160))"
                )
            }

            switch command {
            case .explain:
                return (.explanation(ExplanationTrimmer.trimmed(result), source: .model), nil)
            case .fix where result == frame.core:
                return (.unchanged("Looks right already."), nil)
            case .fix, .shorten:
                return (.replacement(frame.wrapping(result)), nil)
            }
        } catch {
            return (mechanicalFix ?? .failure(Self.refusal(for: command)), "model threw: \(error)")
        }
    }

    /// A fresh session per command, as the polisher does per utterance.
    ///
    /// **Greedy decoding.** The same selection and the same command give the
    /// same result, every time. With default sampling, an unchanged fix
    /// prompt scored 5 of 5 on one run and 1 of 5 on the next; for a
    /// proofreader that variance is simply a defect, and it turned the corpus
    /// into a dice roll.
    ///
    /// **Fix is guided; shorten and explain are plain text.** Guided
    /// generation cannot come back malformed, and fix needs nothing else. But
    /// asked to explain a bare "API", guided generation leaked its own schema
    /// into the answer — "the schema specifies that the 'text' property must
    /// be a string" — and under greedy decoding it echoed every shorten input
    /// verbatim. Plain text did neither.
    private func generate(
        _ command: VoiceCommand,
        from source: String,
        acronyms: [Acronym]
    ) async throws -> String {
        let session = LanguageModelSession(instructions: Self.instructions(for: command))
        let known = command == .explain ? AcronymTable.matches(in: source, from: acronyms) : []
        let prompt = Self.makePrompt(for: command, text: source, known: known)
        let options = GenerationOptions(sampling: .greedy)

        switch command {
        case .fix:
            // The schema is one string field; guided decoding enforces it
            // whether or not the prompt describes it.
            let response = try await session.respond(
                to: prompt,
                generating: Output.self,
                includeSchemaInPrompt: false,
                options: options
            )
            return response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .shorten, .explain:
            let response = try await session.respond(to: prompt, options: options)
            return OutputCleaner.unwrapped(response.content, original: source)
        }
    }

    nonisolated static func refusal(for command: VoiceCommand) -> String {
        switch command {
        case .fix: "Couldn't fix that safely, so your text is unchanged."
        case .shorten: "Couldn't shorten that safely, so your text is unchanged."
        case .explain: "Couldn't explain that."
        }
    }

    // MARK: - Prompts

    /// One instruction set per command. Tuned the way the polisher's are:
    /// with `timbre-eval --commands`, never by eye (ADR-0004).
    nonisolated static func instructions(for command: VoiceCommand) -> String {
        switch command {
        case .fix:
            """
            You proofread text the user has selected. Correct every mechanical error: misspelled \
            words, repeated words, missing or wrong apostrophes (lets becomes let's; its becomes it's \
            where it means "it is"), capital letters at the start of sentences and on names, days \
            and months, and punctuation. Do not rephrase: keep the wording, tone, names, numbers, \
            line breaks and formatting. Do not add or remove information. Text with no errors comes \
            back unchanged. Return only the corrected text.
            """
        case .shorten:
            """
            You are an editor. Rewrite the user's text so that it is about half as long. Keep every \
            fact, name, number and commitment. Keep the author's voice: first person stays first \
            person, and every sentence is a complete, natural sentence. Remove filler, hedging, \
            repetition, pleasantries and throat-clearing. Do not add anything. Return only the \
            rewritten text.
            """
        case .explain:
            """
            You explain a word, acronym or passage the user has selected. Answer in one or two short \
            sentences, under forty words. If it is an acronym, start with what it stands for in the \
            context given, then say what that means. If you are not sure, say that you are not sure \
            instead of guessing. Do not address the user, do not repeat the selection back, and do \
            not add a preamble or a list.
            """
        }
    }

    /// `known` is the taught terms that appear in the selection. They ground
    /// the explanation of a sentence the way an exact match answers a bare term.
    ///
    /// The shorten prompt's shape is all measurement. Fenced, because an
    /// email that opens "Hi Sarah," otherwise reads as a message to pass
    /// through and came back untouched under every variant. Instruction
    /// *after* the text, with a word budget, because before it and without
    /// one the model copied its input four times out of four. And the last
    /// sentence, because without it the budget won and the requests went.
    nonisolated static func makePrompt(
        for command: VoiceCommand,
        text: String,
        known: [Acronym] = []
    ) -> String {
        switch command {
        case .fix:
            return "Correct this text:\n\n\(text)"
        case .shorten:
            let words = text.split(whereSeparator: \.isWhitespace).count
            return """
                Text to shorten:
                \"\"\"
                \(text)
                \"\"\"

                Rewrite the text above more concisely. It has \(words) words; use no more than \
                \(max(words / 2, 1)). Keep who it is addressed to, every fact, and every request.
                """
        case .explain:
            guard !known.isEmpty else { return "Explain this:\n\n\(text)" }
            let definitions = known.map { "\($0.term) means \($0.meaning)" }.joined(separator: "; ")
            return """
                The user's own dictionary defines these terms, and they are correct: \(definitions). \
                Use them exactly.

                Explain this:

                \(text)
                """
        }
    }
}
