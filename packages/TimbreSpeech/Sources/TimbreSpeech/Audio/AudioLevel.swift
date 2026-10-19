import AVFoundation
import Accelerate

/// Loudness metering for the overlay waveform.
///
/// RMS is "average loudness" — peak amplitude would flicker wildly on
/// consonants, while RMS tracks perceived volume. Runs on the real-time
/// audio thread, hence `nonisolated` and Accelerate rather than a Swift loop.
nonisolated enum AudioLevel {

    /// Speech RMS typically sits around 0.01–0.2 of full scale, so raw values
    /// would barely move a meter. Scale up and clamp to a usable 0...1 range.
    private static let meterGain: Float = 6

    static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let samples = UnsafeBufferPointer(start: channelData[0], count: frameLength)
        return normalize(rms: vDSP.rootMeanSquare(samples))
    }

    static func normalize(rms: Float) -> Float {
        min(1, max(0, rms * meterGain))
    }
}
