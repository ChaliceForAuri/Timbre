import Foundation

/// Shapes the user's taught terms into the list handed to the speech model
/// as contextual strings, and measures whether they came back.
///
/// The polisher already sees the vocabulary, but it can only fix what it can
/// still recognise: "timber kit" is recoverable, "superbasin lang views" (for
/// "Supabase and Langfuse") is not. The transcriber would have to get the
/// words right first. `AnalysisContext.contextualStrings` is the
/// `SpeechAnalyzer` mechanism meant for that; `SpeechTranscriber` ignores it
/// today (measured, ADR-0008). This type shapes the list and, more usefully,
/// measures recall so the harness can say so.
nonisolated enum ContextualVocabulary {

    /// Contextual strings beyond this many are dropped, oldest first, so the
    /// word taught a minute ago always makes the list. Apple documents no
    /// limit for `AnalysisContext`; the cap keeps a runaway dictionary from
    /// being handed to the model on every key press.
    static let limit = 100

    /// Trimmed, de-duplicated, capped, original order kept.
    static func strings(from terms: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for term in terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return Array(result.suffix(limit))
    }

    /// The taught terms that did NOT appear verbatim in `transcript`.
    ///
    /// Deliberately case- and spacing-sensitive, unlike `TextMatch`: the whole
    /// point of teaching "SwiftUI" is that it comes back as `SwiftUI`, not
    /// `Swift UI`. This is the number the eval harness reports.
    static func missingTerms(from terms: [String], in transcript: String) -> [String] {
        strings(from: terms).filter { !transcript.contains($0) }
    }
}
