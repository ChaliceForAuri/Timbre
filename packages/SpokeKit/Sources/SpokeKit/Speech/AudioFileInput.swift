import AVFoundation
import Foundation
import Speech

/// Turns a recorded audio file into model-ready input.
///
/// Deliberately *not* `SpeechAnalyzer.start(inputAudioFile:)`, which would have
/// the framework read the file itself. Routing through `BufferConverter` is the
/// entire point: the evaluation harness then exercises the same conversion and
/// end-of-stream drain that microphone audio takes, which is where the subtle
/// bugs live. A file path that bypassed them would pass while the real one
/// clipped every last word.
///
/// Reads eagerly — fixtures are seconds long, and a lazy reader would need its
/// own isolation story for no benefit at this size.
nonisolated enum AudioFileInput {

    static func stream(
        contentsOf url: URL,
        to analyzerFormat: AVAudioFormat,
        chunkFrames: AVAudioFrameCount = 4096
    ) throws -> AsyncStream<AnalyzerInput> {
        let file = try AVAudioFile(forReading: url)
        let converter = BufferConverter()
        var inputs: [AnalyzerInput] = []

        // Bounded by the file's frame count rather than by reading until a
        // short read: `read(into:frameCount:)` fails at EOF rather than
        // returning zero frames, and it reports the failure without setting an
        // error, which surfaces as an opaque `nilError`.
        let totalFrames = file.length
        while file.framePosition < totalFrames {
            let wanted = AVAudioFrameCount(min(Int64(chunkFrames), totalFrames - file.framePosition))
            guard
                let chunk = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: wanted)
            else {
                throw AudioFileError.cannotAllocateBuffer
            }
            try file.read(into: chunk, frameCount: wanted)
            guard chunk.frameLength > 0 else { break }
            inputs.append(AnalyzerInput(buffer: try converter.convert(chunk, to: analyzerFormat)))
        }

        // The converter can still be holding ~100 ms of tail audio. Without
        // this the last word of every fixture is clipped — the same bug the
        // live path has without its drain.
        if let tail = converter.drain(into: analyzerFormat) {
            inputs.append(AnalyzerInput(buffer: tail))
        }

        return AsyncStream { continuation in
            for input in inputs {
                continuation.yield(input)
            }
            continuation.finish()
        }
    }

    enum AudioFileError: LocalizedError {
        case cannotAllocateBuffer

        var errorDescription: String? {
            switch self {
            case .cannotAllocateBuffer:
                return "Could not allocate a buffer to read the audio file."
            }
        }
    }
}
