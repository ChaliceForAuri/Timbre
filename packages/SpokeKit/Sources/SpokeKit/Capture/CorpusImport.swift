import Foundation

/// Turns captured dictations into evaluation cases.
///
/// The checks are left empty on purpose. Only the person who spoke knows which
/// words had to survive and which filler had to go, and a machine guessing at
/// it would produce a corpus that measures nothing. What this does is the
/// tedious half: decode the log, drop what can't be scored, and lay the cases
/// out ready to annotate.
nonisolated public enum CorpusImport {

    /// Decodes JSON Lines, skipping malformed lines rather than failing the
    /// import — a log appended to by a menu bar app can end mid-write.
    public static func records(fromJSONLines contents: String) -> [DictationRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return contents.split(separator: "\n").compactMap { line in
            try? decoder.decode(DictationRecord.self, from: Data(line.utf8))
        }
    }

    /// Builds corpus cases from records, newest last.
    ///
    /// Records whose transcript is empty are dropped: there is nothing to
    /// clean, so the case could never fail and would only pad the score.
    public static func corpus(from records: [DictationRecord]) -> DictationCorpus {
        let cases =
            records
            .filter { !$0.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, record in
                DictationCase(
                    id: String(format: "real-%03d", index + 1),
                    transcript: record.transcript,
                    appContext: record.appContext,
                    note: "Spoke pasted: \(record.polished)"
                )
            }
        return DictationCorpus(cases: cases)
    }
}
