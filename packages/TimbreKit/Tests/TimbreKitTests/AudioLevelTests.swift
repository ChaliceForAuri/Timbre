import AVFoundation
import Testing

@testable import TimbreKit

struct AudioLevelTests {

    private func makeBuffer(filledWith value: Float, frames: AVAudioFrameCount = 1024) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            samples[index] = value
        }
        return buffer
    }

    @Test func silenceMetersAtZero() {
        #expect(AudioLevel.normalizedLevel(of: makeBuffer(filledWith: 0)) == 0)
    }

    @Test func emptyBufferMetersAtZero() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 0
        #expect(AudioLevel.normalizedLevel(of: buffer) == 0)
    }

    @Test func constantSignalMetersAtItsAmplitudeTimesGain() {
        // RMS of a constant 0.1 signal is 0.1; with the 6x meter gain that's 0.6.
        let level = AudioLevel.normalizedLevel(of: makeBuffer(filledWith: 0.1))
        #expect(abs(level - 0.6) < 0.001)
    }

    @Test func loudSignalClampsToOne() {
        #expect(AudioLevel.normalizedLevel(of: makeBuffer(filledWith: 0.9)) == 1)
    }

    @Test func normalizationClampsNegativesToZero() {
        #expect(AudioLevel.normalize(rms: -0.5) == 0)
    }
}
