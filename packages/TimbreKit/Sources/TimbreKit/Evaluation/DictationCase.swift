import Foundation

/// A corpus of dictation samples, loaded from JSON.
nonisolated public struct DictationCorpus: Codable, Sendable {
    public let cases: [DictationCase]

    public init(cases: [DictationCase]) {
        self.cases = cases
    }
}

/// One dictation sample and the properties its cleanup must satisfy.
///
/// Deliberately not an expected-output string. The model is free to punctuate
/// and phrase as it likes, so asserting an exact match would fail on harmless
/// variation and teach us to ignore the suite. Properties survive rewording;
/// exact strings don't.
nonisolated public struct DictationCase: Codable, Sendable, Identifiable {

    /// Stable identifier, used to line runs up when diffing.
    public let id: String

    /// The raw transcript as the speech model would emit it: no punctuation,
    /// fillers intact.
    public let transcript: String

    /// Frontmost app name to pass through, for cases testing tone.
    public let appContext: String?

    /// Terms the user has taught Timbre.
    public let vocabulary: [String]

    /// Phrases that must NOT survive cleanup — fillers, stutters, spoken
    /// formatting commands, or register the polisher shouldn't reach for.
    public let forbidden: [String]

    /// Phrases that must survive. Losing one means the meaning changed.
    public let required: [String]

    /// Whether the output must carry sentence-ending punctuation. Set only on
    /// cases whose input is a run-on.
    public let requiresPunctuation: Bool

    /// Whether the output must contain a line break. Set on cases exercising
    /// spoken structural commands.
    public let requiresLineBreak: Bool

    /// What this case is for, shown in the report.
    public let note: String?

    public init(
        id: String,
        transcript: String,
        appContext: String? = nil,
        vocabulary: [String] = [],
        forbidden: [String] = [],
        required: [String] = [],
        requiresPunctuation: Bool = false,
        requiresLineBreak: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.transcript = transcript
        self.appContext = appContext
        self.vocabulary = vocabulary
        self.forbidden = forbidden
        self.required = required
        self.requiresPunctuation = requiresPunctuation
        self.requiresLineBreak = requiresLineBreak
        self.note = note
    }

    /// Hand-written so every field except `id` and `transcript` may be omitted
    /// from the JSON — synthesized decoding ignores default values and would
    /// make each case carry empty arrays it doesn't use.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        transcript = try container.decode(String.self, forKey: .transcript)
        appContext = try container.decodeIfPresent(String.self, forKey: .appContext)
        vocabulary = try container.decodeIfPresent([String].self, forKey: .vocabulary) ?? []
        forbidden = try container.decodeIfPresent([String].self, forKey: .forbidden) ?? []
        required = try container.decodeIfPresent([String].self, forKey: .required) ?? []
        requiresPunctuation =
            try container.decodeIfPresent(Bool.self, forKey: .requiresPunctuation) ?? false
        requiresLineBreak =
            try container.decodeIfPresent(Bool.self, forKey: .requiresLineBreak) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

/// What one case produced and how it scored.
nonisolated public struct CaseOutcome: Codable, Sendable, Identifiable {
    public let id: String
    public let input: String
    public let output: String
    public let failures: [String]

    public var passed: Bool { failures.isEmpty }

    public init(id: String, input: String, output: String, failures: [String]) {
        self.id = id
        self.input = input
        self.output = output
        self.failures = failures
    }
}

/// Scores polished output against a case's declared properties.
nonisolated public enum PolishChecks {

    /// Every way `output` fails `testCase`, as lines fit to print.
    public static func failures(for testCase: DictationCase, output: String) -> [String] {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ["produced no output"] }

        var failures: [String] = []

        for phrase in testCase.forbidden where TextMatch.containsPhrase(phrase, in: trimmed) {
            failures.append("should have removed \"\(phrase)\"")
        }
        for phrase in testCase.required where !TextMatch.containsPhrase(phrase, in: trimmed) {
            failures.append("lost \"\(phrase)\"")
        }
        if testCase.requiresPunctuation, !trimmed.contains(where: { ".!?".contains($0) }) {
            failures.append("added no sentence punctuation")
        }
        if testCase.requiresLineBreak, !trimmed.contains("\n") {
            failures.append("produced no line break")
        }

        return failures
    }
}
