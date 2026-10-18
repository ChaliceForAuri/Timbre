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

    private static let logger = Logger(subsystem: "dev.hugopretorius.Timbre", category: "audio")

    /// The engine on the system default input, reused across dictations so
    /// a key press pays nothing to build it.
    private let defaultEngine = AVAudioEngine()
    /// Whichever engine is capturing now: the default one, or a fresh one
    /// built for the fallback device, because an I/O unit's device can only
    /// be chosen before it is initialized.
    private var engine: AVAudioEngine
    private var processor: AudioTapProcessor?
    private var isRunning = false
    private var targetFormat: AVAudioFormat?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var levelContinuation: AsyncStream<Float>.Continuation?

    /// Whether the device this capture opened on is a Bluetooth headset —
    /// the only kind that can be connected and silent at once (ADR-0012).
    private(set) var inputIsBluetooth = false

    init() {
        engine = defaultEngine
    }

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

        engine = defaultEngine
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
        targetFormat = format
        self.inputContinuation = inputContinuation
        self.levelContinuation = levelContinuation
        inputIsBluetooth = InputDevices.defaultInput().map(InputDevices.isBluetooth) ?? false

        try installTap(on: input, format: inputFormat)
        isRunning = true

        return Streams(input: inputStream, levels: levelStream)
    }

    /// Moves a running capture onto `device` without touching the streams:
    /// the analyzer keeps consuming the same input sequence, the pill the
    /// same levels, and only the microphone behind them changes. For the
    /// headset that is connected but silent (ADR-0012).
    func switchInput(to device: AudioDeviceID) throws {
        guard isRunning, targetFormat != nil else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        // The old route's converter holds nothing worth keeping — it only
        // ever saw silence — so the processor is dropped, not finished:
        // finishing would end the streams the analyzer is still reading.
        processor = nil

        // A fresh engine: the I/O unit's device must be chosen before the
        // unit is initialized, and the default engine's already was.
        let fallback = AVAudioEngine()
        let input = fallback.inputNode
        guard let unit = input.audioUnit else { throw AudioCaptureError.noInputDevice }
        var id = device
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &id, UInt32(MemoryLayout<AudioDeviceID>.size))
        guard status == noErr else {
            Self.logger.error("could not select input device \(device): \(status)")
            throw AudioCaptureError.noInputDevice
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw AudioCaptureError.noInputDevice }

        engine = fallback
        try installTap(on: input, format: inputFormat)
        inputIsBluetooth = InputDevices.isBluetooth(device)
        Self.logger.log("input switched to \(InputDevices.name(of: device), privacy: .public)")
    }

    private func installTap(on input: AVAudioInputNode, format inputFormat: AVAudioFormat) throws {
        guard let targetFormat, let inputContinuation, let levelContinuation else { return }
        let processor = AudioTapProcessor(
            targetFormat: targetFormat,
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
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        if let processor {
            processor.finish()
        } else {
            // A switch that failed between dropping one processor and
            // installing the next left the streams open; the analyzer is
            // waiting on them, so they must still end here.
            inputContinuation?.finish()
            levelContinuation?.finish()
        }
        processor = nil
        inputContinuation = nil
        levelContinuation = nil
        targetFormat = nil
        engine = defaultEngine
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
