import AVFoundation
import Foundation

/// Reads text aloud with the system's on-device voices, and can change speed
/// without losing your place.
///
/// `AVSpeechUtterance.rate` is fixed once speaking starts — there is no
/// setter that takes effect mid-flight. So speeding up means stopping and
/// starting a new utterance, and the only way that isn't jarring is to
/// resume from exactly where the voice had reached.
/// `willSpeakRangeOfSpeechString` reports that position as it goes; keeping
/// it is what makes a tap feel like a speed knob rather than a restart.
///
/// Voices are on-device (GDR-0001): nothing about the text leaves the Mac.
@MainActor
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()

    /// The text still to be read. Trimmed as speech progresses, so a speed
    /// change simply re-speaks what remains.
    private var remaining = ""

    /// Characters of `remaining` already spoken, per the progress delegate.
    private var spokenPrefix = 0

    /// True while a restart is in flight, so the delegate's `didFinish`
    /// (which fires for the *stopped* utterance) doesn't report completion.
    private var isRestarting = false

    private(set) var speedMultiplier = ReadingSpeed.slowest
    private(set) var isReading = false

    /// Called when the text has been read to the end — not when stopped.
    var onFinish: (@MainActor () -> Void)?

    /// The voice in use, resolved once per read so a newly downloaded voice
    /// is picked up without relaunching.
    private(set) var voice: VoiceCatalog.Option?

    /// When speech last ran, for deciding whether the audio route is still
    /// awake. Nil until the first read of the session.
    private var lastSpokeAt: ContinuousClock.Instant?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Loads voice data ahead of the first real read by speaking a moment of
    /// silence at zero volume. Without it the very first utterance of the
    /// session pays for decoding the voice as well as waking the route.
    func prewarm() {
        guard let identifier = VoiceCatalog.preferred()?.identifier else { return }
        let primer = AVSpeechUtterance(string: " ")
        primer.voice = AVSpeechSynthesisVoice(identifier: identifier)
        primer.volume = 0
        isRestarting = true
        synthesizer.speak(primer)
        isRestarting = false
    }

    /// Starts reading `text` from the beginning at the slowest rung.
    func read(_ text: String) {
        stop()
        remaining = text
        spokenPrefix = 0
        speedMultiplier = ReadingSpeed.slowest
        voice = VoiceCatalog.preferred()
        isReading = true
        speakRemaining()
    }

    /// Climbs one rung of the speed ladder, continuing from the current word.
    /// Returns false when already at the top, so the caller can say so.
    @discardableResult
    func faster() -> Bool {
        guard isReading else { return false }
        let next = ReadingSpeed.next(after: speedMultiplier)
        guard next != speedMultiplier else { return false }

        speedMultiplier = next
        dropSpokenPrefix()

        // Stopping fires didFinish for the utterance being replaced; the
        // flag keeps that from being mistaken for reaching the end.
        isRestarting = true
        synthesizer.stopSpeaking(at: .immediate)
        isRestarting = false

        speakRemaining()
        return true
    }

    func stop() {
        isReading = false
        remaining = ""
        spokenPrefix = 0
        isRestarting = true
        synthesizer.stopSpeaking(at: .immediate)
        isRestarting = false
    }

    // MARK: - Speaking

    private func speakRemaining() {
        guard !remaining.isEmpty else {
            isReading = false
            return
        }
        let utterance = AVSpeechUtterance(string: remaining)
        utterance.rate = ReadingSpeed.utteranceRate(for: speedMultiplier)

        // Silence in front of a cold route, none in front of a warm one.
        // A speed change is by definition warm, so climbing the ladder never
        // pays this.
        let elapsed = lastSpokeAt.map { ContinuousClock.now - $0 }
        utterance.preUtteranceDelay = ReadingWarmup.preRoll(sinceLastSpeech: elapsed)
        lastSpokeAt = ContinuousClock.now

        // Without this the system hands back a compact voice regardless of
        // what better ones are installed.
        if let identifier = voice?.identifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        }
        spokenPrefix = 0
        synthesizer.speak(utterance)
    }

    /// Discards what has already been spoken so the next utterance starts
    /// where the voice actually is.
    private func dropSpokenPrefix() {
        guard spokenPrefix > 0, spokenPrefix <= remaining.count else { return }
        let index = remaining.index(remaining.startIndex, offsetBy: spokenPrefix)
        remaining = String(remaining[index...])
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let location = characterRange.location
        Task { @MainActor in
            // The *start* of the current word, not its end: resuming from
            // mid-word would clip the word the listener is hearing.
            self.spokenPrefix = location
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard !self.isRestarting, self.isReading else { return }
            self.isReading = false
            self.remaining = ""
            self.onFinish?()
        }
    }
}
