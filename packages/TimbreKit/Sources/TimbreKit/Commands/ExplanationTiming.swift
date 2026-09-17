import Foundation

/// How long an explanation stays on screen: long enough to read, never long
/// enough to be in the way. Any new gesture replaces it sooner.
nonisolated enum ExplanationTiming {

    private static let wordsPerSecond = 3.5
    private static let settle = 3.0
    private static let range = 6.0...25.0

    static func displayDuration(for text: String) -> Duration {
        let words = Double(text.split(whereSeparator: \.isWhitespace).count)
        let seconds = min(max(words / wordsPerSecond + settle, range.lowerBound), range.upperBound)
        return .milliseconds(Int(seconds * 1000))
    }
}
