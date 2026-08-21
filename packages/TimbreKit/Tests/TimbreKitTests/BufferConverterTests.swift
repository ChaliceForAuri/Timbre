import AVFoundation
import Testing

@testable import TimbreKit

struct BufferConverterTests {

    private func makeSineBuffer(
        sampleRate: Double,
        channels: AVAudioChannelCount,
        frames: AVAudioFrameCount
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<Int(channels) {
            let samples = buffer.floatChannelData![channel]
            for index in 0..<Int(frames) {
                samples[index] = sin(Float(index) * 0.1)
            }
        }
        return buffer
    }

    @Test func matchingFormatPassesTheSameBufferThrough() throws {
        let converter = BufferConverter()
        let buffer = makeSineBuffer(sampleRate: 16000, channels: 1, frames: 1024)
        let output = try converter.convert(buffer, to: buffer.format)
        #expect(output === buffer)
    }

    @Test func downsamplesToTheTargetRate() throws {
        let converter = BufferConverter()
        let target = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

        // The resampler consumes input in internal quanta and holds the
        // remainder across calls, so the contract is cumulative, not
        // per-buffer: a stream plus a final drain yields input × ratio.
        var totalOutputFrames = 0
        for _ in 0..<10 {
            let input = makeSineBuffer(sampleRate: 48000, channels: 1, frames: 4800)
            let output = try converter.convert(input, to: target)
            #expect(output.format.sampleRate == 16000)
            totalOutputFrames += Int(output.frameLength)
        }
        if let tail = converter.drain(into: target) {
            totalOutputFrames += Int(tail.frameLength)
        }

        // 48 000 input frames at a 1/3 ratio is a nominal 16 000; allow a
        // filter-width of slack either side.
        let nominal = 16000
        #expect(abs(totalOutputFrames - nominal) < 64)
    }

    @Test func drainWithoutConversionYieldsNothing() {
        let converter = BufferConverter()
        let target = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        #expect(converter.drain(into: target) == nil)
    }

    @Test func drainResetsForTheNextSession() throws {
        let converter = BufferConverter()
        let target = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

        let input = makeSineBuffer(sampleRate: 48000, channels: 1, frames: 4800)
        _ = try converter.convert(input, to: target)
        _ = converter.drain(into: target)

        // A fresh session must start from a clean converter — draining twice
        // in a row would otherwise replay stale state.
        #expect(converter.drain(into: target) == nil)

        let next = try converter.convert(input, to: target)
        #expect(next.frameLength > 0)
    }

    @Test func downmixesStereoToMono() throws {
        let converter = BufferConverter()
        let input = makeSineBuffer(sampleRate: 48000, channels: 2, frames: 4800)
        let target = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

        let output = try converter.convert(input, to: target)

        #expect(output.format.channelCount == 1)
        #expect(output.frameLength > 0)
    }

    @Test func survivesAnInputFormatChangeMidStream() throws {
        // The user switches from the built-in mic to AirPods mid-session.
        let converter = BufferConverter()
        let target = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!

        let builtIn = makeSineBuffer(sampleRate: 48000, channels: 1, frames: 4800)
        let airPods = makeSineBuffer(sampleRate: 24000, channels: 1, frames: 2400)

        let first = try converter.convert(builtIn, to: target)
        let second = try converter.convert(airPods, to: target)

        #expect(first.format.sampleRate == 16000)
        #expect(second.format.sampleRate == 16000)
        #expect(second.frameLength > 0)
    }
}
