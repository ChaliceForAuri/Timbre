import AVFoundation
import Foundation

/// Captures microphone audio and hands raw buffers to a callback.
///
/// Flutter/RN note: this is the equivalent of a native module you'd normally
/// have to write by hand. `AVAudioEngine` is a node graph — you tap the input
/// node and get PCM buffers pushed to you on a real-time audio thread.
final class AudioCapture {

    private let engine = AVAudioEngine()
    private var isRunning = false

    /// The hardware format the mic is actually producing. You need this to
    /// build a converter, because the speech model wants its own format.
    var inputFormat: AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    /// Starts capture.
    ///
    /// `onBuffer` and `onLevel` are called on a high-priority audio thread —
    /// do NOT touch UI from inside them. Hop to the main actor first.
    func start(
        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
        onLevel: (@Sendable (Float) -> Void)? = nil
    ) throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        // A 0 sample rate means there's no usable input device (or the node
        // isn't configured). Fail loudly rather than recording nothing.
        //
        // Note this is NOT a permission check — a denied mic permission
        // usually still yields a valid format and then delivers buffers full
        // of zeroes. Permission is handled up front in DictationController
        // via AVCaptureDevice. Never infer permission from audio format.
        guard format.sampleRate > 0 else {
            throw AudioCaptureError.noInputDevice
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            onBuffer(buffer)
            if let onLevel {
                onLevel(Self.rmsLevel(of: buffer))
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    /// Root-mean-square amplitude of a buffer, normalised to roughly 0...1.
    ///
    /// RMS is "average loudness" — it squares every sample (making negatives
    /// positive), averages, then square-roots. Peak amplitude would flicker
    /// wildly on consonants; RMS tracks perceived volume much better.
    private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for index in 0..<frameLength {
            let sample = samples[index]
            sumOfSquares += sample * sample
        }

        let rms = sqrt(sumOfSquares / Float(frameLength))

        // Speech RMS typically sits around 0.01–0.2, so raw values would barely
        // move the meter. Scale up and clamp for a usable visual range.
        return min(1, rms * 6)
    }

    enum AudioCaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice:
                return "No microphone input available. Check System Settings › Privacy & Security › Microphone."
            }
        }
    }
}

/// Converts mic buffers into whatever format the speech model asks for.
///
/// This is the single most common place a first dictation app breaks: the mic
/// gives you 48kHz float, the model wants something else, and if you skip the
/// conversion you get silence or garbage with no error message.
final class BufferConverter {

    private var converter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?

    func convert(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        if inputFormat == targetFormat { return buffer }

        // Rebuild the converter only when the input format actually changes
        // (e.g. the user switches from built-in mic to AirPods mid-session).
        if converter == nil || lastInputFormat != inputFormat {
            guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw ConversionError.cannotCreateConverter
            }
            newConverter.primeMethod = .none  // avoid clipping the start of speech
            converter = newConverter
            lastInputFormat = inputFormat
        }

        guard let converter else { throw ConversionError.cannotCreateConverter }

        // Output capacity has to account for the sample-rate ratio, plus a
        // little headroom, or the converter silently truncates.
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1024

        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw ConversionError.cannotAllocateBuffer
        }

        var consumed = false
        var conversionError: NSError?

        converter.convert(to: output, error: &conversionError) { _, statusPointer in
            if consumed {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed = true
            statusPointer.pointee = .haveData
            return buffer
        }

        if let conversionError { throw conversionError }
        return output
    }

    enum ConversionError: LocalizedError {
        case cannotCreateConverter
        case cannotAllocateBuffer

        var errorDescription: String? {
            switch self {
            case .cannotCreateConverter: return "Could not create an audio format converter."
            case .cannotAllocateBuffer:  return "Could not allocate an audio conversion buffer."
            }
        }
    }
}
