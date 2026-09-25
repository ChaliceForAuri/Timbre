import Foundation

/// A corpus of command-mode samples, loaded from JSON.
nonisolated public struct CommandCorpus: Codable, Sendable {
    public let cases: [CommandCase]

    public init(cases: [CommandCase]) {
        self.cases = cases
    }
}

/// One selection, the command spoken over it, and the properties the result
/// must satisfy. Properties, not expected strings, for the same reason as
/// `DictationCase`: the model is free to word things its own way.
nonisolated public struct CommandCase: Codable, Sendable, Identifiable {
    public let id: String
    public let command: VoiceCommand
    /// The selected text.
    public let text: String
    /// Corrections the user has taught (GDR-0011); `fix` applies them first.
    public let corrections: [Correction]
    /// Terms the user has defined; `explain` answers from them first.
    public let acronyms: [Acronym]
    /// Words the user has taught; the spelling fallback leaves them alone.
    public let vocabulary: [String]
    /// Phrases the result must contain. A trailing `*` matches a word stem.
    public let required: [String]
    /// Phrases the result must not contain.
    public let forbidden: [String]
    /// The exact text the result must be, when only exactness will do ("the", not "The").
    public let exact: String?
    public let note: String?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        command = try container.decode(VoiceCommand.self, forKey: .command)
        text = try container.decode(String.self, forKey: .text)
        corrections = try container.decodeIfPresent([Correction].self, forKey: .corrections) ?? []
        acronyms = try container.decodeIfPresent([Acronym].self, forKey: .acronyms) ?? []
        vocabulary = try container.decodeIfPresent([String].self, forKey: .vocabulary) ?? []
        required = try container.decodeIfPresent([String].self, forKey: .required) ?? []
        forbidden = try container.decodeIfPresent([String].self, forKey: .forbidden) ?? []
        exact = try container.decodeIfPresent(String.self, forKey: .exact)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

/// What a command produced, flattened for the harness.
nonisolated public struct CommandResult: Sendable, Equatable {
    public enum Kind: String, Sendable { case replacement, explanation, unchanged, failure }

    public let kind: Kind
    /// The replacement, the explanation, the untouched text, or the failure message.
    public let text: String
    /// Why a failure failed — guardrail or thrown error — for the harness.
    public let diagnostic: String?

    public init(kind: Kind, text: String, diagnostic: String? = nil) {
        self.kind = kind
        self.text = text
        self.diagnostic = diagnostic
    }
}

nonisolated public enum CommandChecks {

    /// Every way `result` fails `testCase`, as lines fit to print.
    public static func failures(for testCase: CommandCase, result: CommandResult) -> [String] {
        var failures: [String] = []

        switch (testCase.command, result.kind) {
        case (_, .failure):
            return ["did nothing: \(result.text)"]
        case (.explain, .explanation), (.fix, .replacement), (.fix, .unchanged), (.shorten, .replacement),
            (.plain, .replacement), (.plain, .unchanged):
            break
        default:
            failures.append("\(testCase.command.rawValue) produced a \(result.kind.rawValue)")
        }

        if testCase.command == .shorten, result.text.count >= testCase.text.count {
            failures.append("is not shorter")
        }
        for phrase in testCase.forbidden where contains(phrase, in: result.text) {
            failures.append("still contains \"\(phrase)\"")
        }
        for phrase in testCase.required where !contains(phrase, in: result.text) {
            failures.append("lost \"\(phrase)\"")
        }
        if let exact = testCase.exact, result.text.trimmingCharacters(in: .whitespacesAndNewlines) != exact {
            failures.append("is \"\(result.text)\", not exactly \"\(exact)\"")
        }
        return failures
    }

    /// `TextMatch`, plus a trailing `*` for a word stem: "architect*" accepts
    /// architecture and architectural. An explanation is free prose, and a
    /// check that fails a correct answer for its grammar teaches us to ignore
    /// the suite.
    static func contains(_ phrase: String, in text: String) -> Bool {
        guard phrase.hasSuffix("*") else { return TextMatch.containsPhrase(phrase, in: text) }
        let stem = TextMatch.normalized(String(phrase.dropLast()))
        guard !stem.isEmpty else { return false }
        return TextMatch.normalized(text).split(separator: " ").contains { $0.hasPrefix(stem) }
    }
}
