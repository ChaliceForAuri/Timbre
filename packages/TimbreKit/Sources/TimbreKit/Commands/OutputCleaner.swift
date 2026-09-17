import Foundation

/// Removes the wrapping a plain-text answer sometimes arrives in.
///
/// Shorten and explain generate plain text (see `TextTransformer.generate`),
/// and the shorten prompt fences the selection in triple quotes. A model that
/// mirrors the fence back, or quotes its whole answer, would paste those
/// quotes into the user's document.
nonisolated enum OutputCleaner {

    static func unwrapped(_ output: String, original: String) -> String {
        var text = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.hasPrefix("\"\"\""), text.hasSuffix("\"\"\""), text.count >= 6 {
            text = String(text.dropFirst(3).dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // One pair of quotes around the whole answer, when the selection had
        // none: the model quoting its result, not the author quoting someone.
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        for (open, close) in [("\"", "\""), ("“", "”")] where !original.hasPrefix(open) {
            let inner = text.dropFirst().dropLast()
            if text.count >= 2, text.hasPrefix(open), text.hasSuffix(close), !inner.contains(open),
                !inner.contains(close)
            {
                text = String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
}
