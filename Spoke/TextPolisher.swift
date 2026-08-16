import Foundation
import FoundationModels

/// The cleanup layer — this is the part that makes dictation feel like writing.
///
/// Wispr Flow runs a fine-tuned Llama in their cloud to do exactly this, and
/// it's the real reason people pay $15/month. Apple hands you an equivalent
/// ~3B model on-device for free. This file is your whole competitive answer
/// to their most expensive component.
///
/// Tuning the `instructions` below is where you'll get the most product value
/// per hour spent. Treat it as the core of the app, not boilerplate.
@available(macOS 26.0, *)
final class TextPolisher {

    /// Structured output. `@Generable` makes the model return this shape
    /// reliably instead of you regex-parsing prose out of a text blob.
    ///
    /// RN/Flutter note: this is like a schema-validated API response, except
    /// the schema is enforced during token generation, so it can't come back
    /// malformed.
    @Generable
    struct Polished {
        @Guide(description: "The cleaned-up text, ready to paste. Never add commentary, quotes, or explanation.")
        var text: String
    }

    /// Whether the on-device model is usable right now.
    /// Returns a human-readable reason when it isn't.
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

    private let instructions = """
    You clean up dictated speech so it reads as if the person had typed it.

    Rules, in priority order:
    1. Never change the meaning. Never add facts, opinions, or sentences the \
    speaker did not say. If you are unsure, leave the wording alone.
    2. Remove filler: um, uh, like, you know, I mean, sort of, false starts, \
    and repeated words caused by the speaker restarting a sentence.
    3. Add correct punctuation and capitalization. Break run-on speech into \
    sentences.
    4. Obey spoken formatting commands and remove them from the output: \
    "new paragraph", "new line", "bullet point", "period", "comma", \
    "question mark", "open quote", "close quote".
    5. Keep the speaker's own voice and vocabulary. Do not make casual speech \
    formal, do not upgrade simple words to fancy ones, do not reorganize \
    their argument. You are a transcriptionist, not an editor.
    6. Return only the cleaned text. No preamble, no quotes around it, no \
    notes about what you changed.
    """

    /// Cleans a raw transcript. Falls back to the raw text on any failure —
    /// the user should always get something pasteable, even if the model is
    /// busy or unavailable.
    func polish(_ raw: String, appContext: String? = nil, vocabulary: [String] = []) async -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard Self.availability.isReady else { return trimmed }

        var prompt = ""

        // Context awareness: Wispr adapts tone to the app you're typing into.
        // Passing the frontmost app name is a cheap way to match that.
        if let appContext, !appContext.isEmpty {
            prompt += """
            The text will be pasted into \(appContext). Match the register that \
            app usually calls for, but do not rewrite the speaker's words to do it.

            """
        }

        // Personal vocabulary: this is where you beat everyone. A local model
        // can learn the user's jargon with zero privacy cost.
        if !vocabulary.isEmpty {
            let list = vocabulary.prefix(60).joined(separator: ", ")
            prompt += """
            These terms are spelled correctly and appear often in this user's \
            writing. Prefer them over similar-sounding alternatives: \(list).

            """
        }

        prompt += """
        Clean up this dictation:

        \(trimmed)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: Polished.self)
            let cleaned = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Guardrail against the classic failure mode: the model "helpfully"
            // rewrites three sentences into one, or refuses and explains itself.
            // If the length is wildly off, trust the raw transcript instead.
            let ratio = Double(cleaned.count) / Double(max(trimmed.count, 1))
            guard !cleaned.isEmpty, ratio > 0.4, ratio < 2.5 else { return trimmed }

            return cleaned
        } catch {
            return trimmed
        }
    }
}
