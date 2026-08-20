import AVFoundation
import Speech
import os

/// Captures microphone audio and exposes it as async streams.
///
/// The format conversion happens *on the audio thread*, so what crosses the
/// concurrency boundary is `AnalyzerInput` — which Apple marks `Sendable` for
/// exactly this purpose — never a raw `AVAudioPCMBuffer`. This is what lets
/// the whole pipeline compile under strict concurrency with no escape
/// hatches of our own (see ADR-0001).
final class AudioCapture {

    /// Model-ready audio plus meter levels for the overlay waveform.
    struct Streams {
        let input: AsyncStream<AnalyzerInput>
        let levels: AsyncStream<Float>
    }

    private let engine = AVAudioEngine()
    private var processor: AudioTapProcessor?
    private var isRunning = false

    /// Whether the current/most recent capture delivered any buffers at all.
    /// A running engine with a vanished device (Bluetooth headphones taken
    /// off, no mic connected) starts cleanly and then delivers nothing —
    /// callers need to tell that apart from a short utterance.
    var hasDeliveredAudio: Bool {
        processor?.hasDeliveredAudio ?? false
    }

    /// Starts capture, converting every buffer to `format` before it leaves
    /// the audio thread. Both streams finish when `stop()` is called.
    func start(convertingTo format: AVAudioFormat) throws -> Streams {
        precondition(!isRunning, "AudioCapture is already running")

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // A 0 sample rate means there's no usable input device. Fail loudly
        // rather than recording nothing.
        //
        // Note this is NOT a permission check — a denied mic permission
        // usually still yields a valid format and then delivers buffers full
        // of zeroes. Permission is handled up front in DictationController.
        guard inputFormat.sampleRate > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        let (levelStream, levelContinuation) = AsyncStream<Float>.makeStream()

        let processor = AudioTapProcessor(
            targetFormat: format,
            input: inputContinuation,
            levels: levelContinuation
        )
        self.processor = processor

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            @Sendable buffer, _ in
            processor.process(buffer)
        }

        engine.prepare()
        try engine.start()
        isRunning = true

        return Streams(input: inputStream, levels: levelStream)
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        processor?.finish()
        processor = nil
        isRunning = false
    }

    enum AudioCaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice:
                return
                    "No microphone input available. Check System Settings › Privacy & Security › Microphone."
            }
        }
    }
}

/// The audio-thread side of capture: meters the buffer, converts it, and
/// yields it into the streams.
///
/// `@unchecked Sendable` is justified because `AVAudioEngine` invokes the tap
/// serially from a single real-time thread, and `finish()` — the only other
/// entry point — is called strictly after `removeTap` + `engine.stop()`,
/// which is the happens-before that ends audio-thread access.
private nonisolated final class AudioTapProcessor: @unchecked Sendable {

    private let converter = BufferConverter()
    private let targetFormat: AVAudioFormat
    private let input: AsyncStream<AnalyzerInput>.Continuation
    private let levels: AsyncStream<Float>.Continuation
    private let delivered = OSAllocatedUnfairLock(initialState: false)

    var hasDeliveredAudio: Bool {
        delivered.withLock { $0 }
    }

    init(
        targetFormat: AVAudioFormat,
        input: AsyncStream<AnalyzerInput>.Continuation,
        levels: AsyncStream<Float>.Continuation
    ) {
        self.targetFormat = targetFormat
        self.input = input
        self.levels = levels
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        delivered.withLock { $0 = true }
        levels.yield(AudioLevel.normalizedLevel(of: buffer))

        // Dropping a single unconvertible buffer is better than tearing down
        // the whole session.
        guard let converted = try? converter.convert(buffer, to: targetFormat) else { return }
        input.yield(AnalyzerInput(buffer: converted))
    }

    func finish() {
        // The converter can be holding the tail of the user's last word;
        // flush it into the stream before closing.
        if let tail = converter.drain(into: targetFormat) {
            input.yield(AnalyzerInput(buffer: tail))
        }
        input.finish()
        levels.finish()
    }
}
