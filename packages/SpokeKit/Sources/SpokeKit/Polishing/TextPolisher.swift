import Foundation
import FoundationModels

/// The cleanup layer — the part that makes dictation feel like writing.
///
/// Wispr Flow runs a fine-tuned Llama in their cloud to do exactly this;
/// Apple hands us an equivalent ~3B model on-device for free. Tuning the
/// `instructions` below is where the product lives. Treat it as the core of
/// the app, not boilerplate.
final class TextPolisher {

    /// Structured output. `@Generable` enforces the shape during token
    /// generation, so the response can't come back malformed.
    @Generable
    nonisolated struct Polished {
        @Guide(
            description:
                "The cleaned-up text, ready to paste. Never add commentary, quotes, or explanation."
        )
        var text: String
    }

    /// Whether the on-device model is usable right now, with a
    /// human-readable reason when it isn't.
    static var availability: (isReady: Bool, reason: String?) {
        switch SystemLanguageModel.default.availability {
        case .available:
            return (true, nil)
        case .unavailable(.deviceNotEligible):
            return (false, "This Mac doesn't support Apple Intelligence (Apple Silicon required).")
        case .unavailable(.appleIntelligenceNotEnabled):
            return (false, "Turn on Apple Intelligence in System Settings.")
        case .unavailable(.modelNotReady):
            return (false, "The on-device model is still downloading. Try again shortly.")
        case .unavailable:
            return (false, "The on-device model is unavailable right now.")
        }
    }

    private static let instructions = """
        You clean up dictated speech so it reads as if the person had typed it.

        Rules, in priority order:
        1. Never change the meaning. Never add facts, opinions, or sentences the \
        speaker did not say. If you are unsure, leave the wording alone.
        2. Remove filler: um, uh, like, you know, I mean, sort of, false starts, \
        and repeated words caused by the speaker restarting a sentence.
        3. Add correct punctuation and capitalization. Break run-on speech into \
        sentences. (The final full stop is added deterministically afterwards, \
        so it is not your concern — see SentenceTerminator.)
        4. Preserve the line breaks and blank lines already in the text. They are \
        deliberate structure, not accidents of speech — do not join those lines \
        into a paragraph.
        5. Keep the speaker's own voice and vocabulary. Do not make casual speech \
        formal, do not upgrade simple words to fancy ones, do not reorganize \
        their argument. You are a transcriptionist, not an editor.
        6. Return only the cleaned text. No preamble, no quotes around it, no \
        notes about what you changed.
        """

    /// Vocabulary beyond this many terms is dropped from the prompt — the
    /// context window is small and recall degrades long before it fills.
    private nonisolated static let vocabularyPromptLimit = 60

    /// Pages the model weights in so the first real polish isn't the slow one.
    func prewarm() {
        guard Self.availability.isReady else { return }
        LanguageModelSession(instructions: Self.instructions).prewarm()
    }

    /// Cleans a raw transcript. Falls back to the raw text on any failure —
    /// the user must always get something pasteable, even if the model is
    /// busy or unavailable.
    func polish(_ raw: String, appContext: String? = nil, vocabulary: [String] = []) async -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Structural commands resolve before the model sees the text, so it
        // punctuates around real breaks instead of around the words that named
        // them (GDR-0003).
        let structured = SpokenCommands.applied(to: trimmed)

        // One exit point, so the terminal-punctuation guarantee holds on every
        // path — including the fallbacks, where the model never ran. ADR-0005.
        return SentenceTerminator.terminated(
            await modelCleanup(of: structured, appContext: appContext, vocabulary: vocabulary)
        )
    }

    /// The model half of `polish`. Returns `trimmed` unchanged whenever the
    /// model is unavailable, errors, or produces something the guardrail
    /// rejects — the user never loses an utterance to cleverness.
    private func modelCleanup(
        of trimmed: String,
        appContext: String?,
        vocabulary: [String]
    ) async -> String {
        guard Self.availability.isReady else { return trimmed }

        let prompt = Self.makePrompt(transcript: trimmed, appContext: appContext, vocabulary: vocabulary)

        do {
            // A fresh session per utterance: no cross-utterance contamination.
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(to: prompt, generating: Polished.self)
            let cleaned = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard PolishGuardrail.accepts(cleaned: cleaned, raw: trimmed) else { return trimmed }
            return cleaned
        } catch {
            return trimmed
        }
    }

    /// Prompt assembly, separated from the model call so it's testable.
    nonisolated static func makePrompt(
        transcript: String,
        appContext: String?,
        vocabulary: [String]
    ) -> String {
        var prompt = ""

        // Context awareness: adapt tone to the app the text will land in.
        if let appContext, !appContext.isEmpty {
            prompt += """
                The text will be pasted into \(appContext). Match the register that \
                app usually calls for, but do not rewrite the speaker's words to do it.


                """
        }

        // Personal vocabulary: a local model can learn the user's jargon
        // with zero privacy cost. This is where Spoke beats the cloud apps.
        if !vocabulary.isEmpty {
            let list = vocabulary.prefix(vocabularyPromptLimit).joined(separator: ", ")
            prompt += """
                These terms are spelled correctly and appear often in this user's \
                writing. Prefer them over similar-sounding alternatives: \(list).


                """
        }

        prompt += """
            Clean up this dictation:

            \(transcript)
            """

        return prompt
    }
}
