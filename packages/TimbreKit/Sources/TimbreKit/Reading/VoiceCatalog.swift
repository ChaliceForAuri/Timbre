import AVFoundation

/// Picks the best voice available, and knows when the best is not good.
///
/// macOS ships dozens of *compact* voices and treats the good ones —
/// Enhanced and Premium — as optional downloads. An `AVSpeechUtterance`
/// with no voice set gets the system default, which on a fresh Mac is a
/// compact voice that sounds like 2005. Choosing deliberately is the
/// difference between "the voice is terrible" and a usable feature.
nonisolated enum VoiceCatalog {

    /// A voice reduced to what choosing actually depends on, so the choice
    /// is testable without the speech framework.
    struct Option: Equatable, Sendable {
        let identifier: String
        let name: String
        /// BCP-47, e.g. "en-GB".
        let language: String
        /// Higher is better: premium 3, enhanced 2, compact 1.
        let qualityRank: Int

        var isHighQuality: Bool { qualityRank >= 2 }
    }

    static func rank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }

    /// The best match for `locale`, preferring an exact language-region
    /// match over a same-language one, and higher quality over lower.
    ///
    /// Region matters before quality: a Premium American voice reading
    /// British English is a worse experience than an Enhanced British one,
    /// because the mispronunciations are what listeners notice.
    static func choose(from options: [Option], preferring locale: String) -> Option? {
        let language = String(locale.prefix(2))

        let exact = options.filter { $0.language.caseInsensitiveCompare(locale) == .orderedSame }
        let sameLanguage = options.filter { $0.language.hasPrefix(language) }

        return best(of: exact) ?? best(of: sameLanguage) ?? best(of: options)
    }

    private static func best(of options: [Option]) -> Option? {
        options.max { left, right in
            if left.qualityRank != right.qualityRank { return left.qualityRank < right.qualityRank }
            // Stable tiebreak so the chosen voice doesn't wander between
            // launches as the system reorders its list.
            return left.identifier > right.identifier
        }
    }

    // MARK: - Live catalogue

    static var installed: [Option] {
        AVSpeechSynthesisVoice.speechVoices().map {
            Option(
                identifier: $0.identifier,
                name: $0.name,
                language: $0.language,
                qualityRank: rank($0.quality)
            )
        }
    }

    /// The voice Timbre should use right now, given the user's locale.
    static func preferred(for locale: Locale = .current) -> Option? {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        return choose(from: installed, preferring: identifier)
    }
}
