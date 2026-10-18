import Foundation

/// Turns spoken structural commands into the breaks they name, before the
/// transcript reaches the model.
///
/// Only *structural* commands are supported. Punctuation commands — "period",
/// "comma", "question mark" — are deliberately absent: they are ordinary
/// English words ("the Victorian period", "a grace period"), so replacing them
/// blindly corrupts real speech, and the polisher already punctuates correctly
/// without being told to. See GDR-0003.
///
/// Applied *before* the model rather than after, so the model sees real line
/// breaks and can punctuate around them. Run afterwards it would be fighting
/// output like "Send it to the team. New paragraph." where the command has
/// already been capitalised into a sentence of its own.
nonisolated enum SpokenCommands {

    /// Longest first: "new paragraph" must not be partly eaten by a shorter
    /// pattern, and future additions shouldn't have to think about ordering.
    private static let commands: [(spoken: String, written: String)] = [
        ("new paragraph", "\n\n"),
        ("bullet point", "\n• "),
        ("new line", "\n"),
    ]

    /// Replaces each command with its break, absorbing the whitespace around
    /// it so "team new paragraph let" becomes "team\n\nlet" rather than
    /// "team \n\n let". The transcriber punctuates as it goes, so the command
    /// arrives as "New paragraph." — the stop it was given is absorbed too;
    /// the sentence before it keeps its own.
    static func applied(to transcript: String) -> String {
        replaced(in: transcript).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The breaks alone, when the utterance was nothing but commands — "new
    /// paragraph", said on its own, means a paragraph break and no words.
    /// Nil when there were words.
    static func onlyCommands(in transcript: String) -> String? {
        let result = replaced(in: transcript)
        let words = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard words.isEmpty, result != transcript, !result.isEmpty else { return nil }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func replaced(in transcript: String) -> String {
        var result = transcript
        for (spoken, written) in commands {
            let escaped = NSRegularExpression.escapedPattern(for: spoken)
            result = result.replacingOccurrences(
                of: "[ \\t]*\\b\(escaped)\\b[.,;:!?]*[ \\t]*",
                with: written,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }
}
