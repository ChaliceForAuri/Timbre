import AVFoundation

/// Converts mic buffers into whatever format the speech model asks for.
///
/// This is the single most common place a first dictation app breaks: the mic
/// gives you 48 kHz float, the model wants something else, and if you skip
/// the conversion you get silence or garbage with no error message.
///
/// Not thread-safe by itself — each instance must be confined to one thread.
/// In Spoke that's the real-time audio thread, via `AudioTapProcessor`.
nonisolated final class BufferConverter {

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

    /// Flushes what the converter still holds and resets it for a new stream.
    ///
    /// The resampler consumes input in internal quanta and can be holding up
    /// to ~100 ms of audio when a session stops — the tail of the user's last
    /// word. Call this once at end of stream and feed the result onward;
    /// skipping it silently clips the end of every utterance.
    func drain(into targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter else { return nil }
        defer {
            self.converter = nil
            lastInputFormat = nil
        }

        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 8192) else {
            return nil
        }

        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, statusPointer in
            statusPointer.pointee = .endOfStream
            return nil
        }

        guard conversionError == nil, output.frameLength > 0 else { return nil }
        return output
    }

    enum ConversionError: Error {
        case cannotCreateConverter
        case cannotAllocateBuffer
    }
}
