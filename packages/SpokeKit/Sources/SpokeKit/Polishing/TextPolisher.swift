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
        // A constraint stated here lands harder than the same rule in
        // `instructions` — this description sits at the generation site.
        // Terminal punctuation was in rule 3 and still came back missing
        // until it was said in both places.
        @Guide(
            description: """
                The cleaned-up text, ready to paste. It ends with sentence-ending \
                punctuation. Never add commentary, quotes, or explanation.
                """
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
        sentences. Every sentence ends with a full stop, question mark, or \
        exclamation mark, including the last sentence in the text.
        4. Spoken formatting commands are instructions, not words to transcribe. \
        Replace each one with the punctuation or line break it names and delete \
        the words themselves: "new paragraph", "new line", "bullet point", \
        "period", "comma", "question mark", "open quote", "close quote". \
        For example, "send it to the team period new paragraph let me know if \
        anything breaks" becomes "Send it to the team." followed by a blank \
        line and then "Let me know if anything breaks."
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
