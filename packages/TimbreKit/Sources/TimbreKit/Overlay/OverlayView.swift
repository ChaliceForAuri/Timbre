import SwiftUI

/// The pill that floats near the cursor while the user talks.
///
/// Design intent: this is the app's entire personality. It has to appear
/// instantly (any lag reads as "did it hear me?"), show that audio is being
/// received (the bars), and show words landing in real time (the text).
/// Those three signals are what make dictation feel trustworthy instead of
/// like shouting into a void.
struct OverlayView: View {

    enum Mode: Equatable {
        /// The engine is starting and no audio has arrived yet. Saying
        /// "Listening" here would be a lie that invites speech into dead
        /// air — on a Bluetooth mic the wake can take half a second.
        case warming
        case listening
        /// Reading a selection aloud, showing the current speed.
        case reading(speed: String)
        case polishing
        /// Right ⌘ held over a selection: waiting for fix, explain or shorten.
        case command
        /// A command is running on the selection.
        case working(String)
        /// The answer to "explain", carried in `text` as it streams in. A
        /// card rather than a pill: it is shown, never pasted, and stays long
        /// enough to read. The caption says where the answer came from. The
        /// answer is not part of the mode on purpose — the view animates mode
        /// changes, and every streamed word would otherwise be one.
        case explanation(caption: String)
        /// Something worth saying that is not a failure.
        case notice(String)
        case error(String)
    }

    let mode: Mode
    let text: String
    /// Recent audio levels, 0...1, oldest first. Drives the waveform.
    let levels: [Float]

    var body: some View {
        HStack(alignment: isCard ? .top : .center, spacing: 12) {
            indicator

            if !displayText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textColor)
                        .lineLimit(isCard ? 14 : 2)
                        // A transcript keeps its END visible — that's the
                        // newest speech. An explanation is read from the start.
                        .truncationMode(isCard ? .tail : .head)
                        .fixedSize(horizontal: false, vertical: true)

                    if let caption {
                        Text(caption)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: isCard ? 380 : 320, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isCard ? 12 : 10)
        .background {
            // Native vibrancy: what makes it look like part of macOS rather
            // than a web page pretending to be a Mac app.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        // Deliberately no animation on the text. Partial results arrive in
        // bursts — 31 of them in five seconds is typical — so animating each
        // one leaves overlapping layout animations permanently in flight, and
        // the panel samples its size in the middle of them.
        .animation(.smooth(duration: 0.2), value: mode)
    }

    // MARK: - Pieces

    private var isCard: Bool {
        if case .explanation = mode { return true }
        return false
    }

    private var caption: String? {
        if case .explanation(let caption) = mode { return caption }
        return nil
    }

    @ViewBuilder
    private var indicator: some View {
        switch mode {
        case .warming, .listening, .command:
            Waveform(levels: levels)
                .frame(width: 34, height: 18)
        case .reading:
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
        case .polishing, .working:
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        case .explanation:
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.top, 1)
        case .notice:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    private var displayText: String {
        switch mode {
        case .warming: "Waking the mic…"
        case .reading(let speed): "Reading  \(speed)"
        case .listening: text.isEmpty ? "Listening…" : text
        case .polishing: text.isEmpty ? "Cleaning up…" : text
        case .command: text.isEmpty ? VoiceCommand.hint : text
        case .working(let label): label
        case .explanation: text.isEmpty ? "Explaining…" : text
        case .notice(let message): message
        case .error(let message): message
        }
    }

    private var textColor: Color {
        switch mode {
        case .warming, .polishing, .working: .secondary
        case .reading, .explanation, .notice, .error: .primary
        case .listening, .command: text.isEmpty ? .secondary : .primary
        }
    }
}

/// A tiny live audio meter.
///
/// Deliberately not a real FFT — nobody can read a spectrum at this size.
/// What the user needs is "the app can hear me", which amplitude bars convey
/// instantly and cheaply.
struct Waveform: View {
    let levels: [Float]

    private let barCount = 5

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(.tint)
                    .frame(width: 3, height: height(for: index))
            }
        }
        .animation(.easeOut(duration: 0.1), value: levels)
    }

    private func height(for index: Int) -> CGFloat {
        // Map the most recent samples onto the bars, newest on the right.
        let sampleIndex = levels.count - barCount + index
        let level = levels.indices.contains(sampleIndex) ? levels[sampleIndex] : 0

        // Perceptual curve: raw RMS looks dead because quiet speech is a tiny
        // fraction of full scale. sqrt spreads the low end out visually.
        let curved = CGFloat(sqrt(max(0, min(1, level))))
        let minHeight: CGFloat = 3
        let maxHeight: CGFloat = 18
        return minHeight + curved * (maxHeight - minHeight)
    }
}

#Preview("Listening") {
    OverlayView(
        mode: .listening,
        text: "so the thing I wanted to say about the architecture",
        levels: [0.1, 0.4, 0.8, 0.3, 0.6]
    )
    .padding(40)
}

#Preview("Command") {
    OverlayView(mode: .command, text: "", levels: [0.1, 0.2, 0.1, 0.3, 0.2])
        .padding(40)
}

#Preview("Explanation") {
    OverlayView(
        mode: .explanation(caption: "On-device model · may be wrong"),
        text: "ADR stands for Architecture Decision Record: a short document that captures one "
            + "significant technical choice, the context that forced it, and its consequences.",
        levels: []
    )
    .padding(40)
}
