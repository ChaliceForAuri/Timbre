import AVFoundation
import Foundation
import Testing

@testable import TimbreKit

@Suite("AudioFileInput")
struct AudioFileInputTests {

    /// Regression: `AVAudioFile.read(into:frameCount:)` *fails* once the read
    /// head is at the end of the file rather than returning zero frames, and
    /// it fails without populating the error pointer — which surfaces as an
    /// opaque `nilError` with nothing to debug from. Bounding the loop by the
    /// file's frame count is what keeps that from happening, so a file whose
    /// length is not a multiple of the chunk size has to stay covered.
    @Test("Reads a file whose length is not a whole number of chunks")
    func readsUnalignedFile() async throws {
        let sourceFormat = try #require(
            AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)
        )
        let targetFormat = try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            )
        )

        let frameCount: AVAudioFrameCount = 4096 * 2 + 1234
        let url = URL(filePath: NSTemporaryDirectory())
            .appending(path: "timbre-audiofileinput-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }

        try write(frames: frameCount, format: sourceFormat, to: url)

        var totalFrames: AVAudioFrameCount = 0
        for await input in try AudioFileInput.stream(contentsOf: url, to: targetFormat) {
            totalFrames += input.buffer.frameLength
        }

        // Resampling 22.05 kHz down to 16 kHz, so expect the ratio applied.
        // Exactness isn't the point — not losing the tail is.
        let expected = Double(frameCount) * 16000 / 22050
        #expect(totalFrames > 0)
        #expect(abs(Double(totalFrames) - expected) < 512)
    }

    private func write(frames: AVAudioFrameCount, format: AVAudioFormat, to url: URL) throws {
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames

        // A quiet tone rather than silence: a resampler fed pure zeroes can
        // legitimately produce nothing, which would hide a real regression.
        if let channel = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frames) {
                channel[frame] = 0.1 * sin(Float(frame) * 0.05)
            }
        }
        try file.write(from: buffer)
    }
}
