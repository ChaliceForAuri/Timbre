import Foundation

/// The check on a model-written example sentence (GDR-0027, property 4):
/// the sentence must use the word, be a sentence or two of ordinary length,
/// and arrive as prose — not quoted, not prefaced, not a template. Anything
/// that fails is not shown; the card says there is no example rather than
/// showing a bad one. Deterministic, so the harness can score it.
nonisolated public enum ExampleGuardrail {

    public enum Failure: String, Sendable, CaseIterable {
        case empty
        case missingTerm
        case tooShort
        case tooLong
        case tooManySentences
        case quoted
        case prefaced
        case placeholder
    }

    public static let minimumWords = 6
    public static let maximumWords = 36
    public static let maximumSentences = 2

    /// Every rule the example breaks; empty when it passes.
    public static func failures(in example: String, for term: String) -> [Failure] {
        let text = example.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [.empty] }
        var failures: [Failure] = []
        if !MetDetector.contains(term, in: text) { failures.append(.missingTerm) }
        let words = text.split(whereSeparator: \.isWhitespace).count
        if words < minimumWords { failures.append(.tooShort) }
        if words > maximumWords { failures.append(.tooLong) }
        if sentenceCount(of: text) > maximumSentences { failures.append(.tooManySentences) }
        if let first = text.first, let last = text.last, "\"“'‘".contains(first), "\"”'’".contains(last) {
            failures.append(.quoted)
        }
        if prefaces.contains(where: { text.lowercased().hasPrefix($0) }) { failures.append(.prefaced) }
        if text.contains(where: { "[]<>{}_".contains($0) }) || text.contains("...") && text.hasSuffix("...") {
            failures.append(.placeholder)
        }
        return failures
    }

    /// The example, trimmed, when it passes; nil when it does not.
    public static func accepted(_ example: String, for term: String) -> String? {
        failures(in: example, for: term).isEmpty
            ? example.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    static func sentenceCount(of text: String) -> Int {
        max(1, text.filter { ".!?".contains($0) }.count)
    }

    /// How a model starts when it is answering instead of writing.
    static let prefaces = [
        "example:", "here is", "here's", "sure", "certainly", "sentence:", "of course", "the word",
    ]
}
