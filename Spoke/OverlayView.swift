import SwiftUI

/// The pill that floats near your cursor while you talk.
///
/// Design intent: this is the app's entire personality. It has to appear
/// instantly (any lag reads as "did it hear me?"), show that audio is being
/// received (the bars), and show words landing in real time (the text). Those
/// three signals are what make dictation feel trustworthy instead of like
/// shouting into a void.
struct OverlayView: View {

    enum Mode: Equatable {
        case listening
        case polishing
        case error(String)
    }

    let mode: Mode
    let text: String
    /// Recent audio levels, 0...1, oldest first. Drives the waveform.
    let levels: [Float]

    var body: some View {
        HStack(spacing: 12) {
            indicator

            if !displayText.isEmpty {
                Text(displayText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .truncationMode(.head)   // keep the END visible — that's the newest speech
                    .frame(maxWidth: 320, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            // Native vibrancy. This is what makes it look like part of macOS
            // rather than a web page pretending to be a Mac app.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .animation(.smooth(duration: 0.18), value: displayText)
        .animation(.smooth(duration: 0.2), value: mode)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var indicator: some View {
        switch mode {
        case .listening:
            Waveform(levels: levels)
                .frame(width: 34, height: 18)
        case .polishing:
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    private var displayText: String {
        switch mode {
        case .listening:      return text.isEmpty ? "Listening…" : text
        case .polishing:      return text.isEmpty ? "Cleaning up…" : text
        case .error(let msg): return msg
        }
    }

    private var textColor: Color {
        switch mode {
        case .listening:  return text.isEmpty ? .secondary : .primary
        case .polishing:  return .secondary
        case .error:      return .primary
        }
    }
}

/// A tiny live audio meter.
///
/// Deliberately not a real FFT — users can't read a spectrum at this size.
/// What they need is "the app can hear me", which amplitude bars convey
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
        let level = (sampleIndex >= 0 && sampleIndex < levels.count) ? levels[sampleIndex] : 0

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

#Preview("Empty") {
    OverlayView(mode: .listening, text: "", levels: [0, 0, 0, 0, 0])
        .padding(40)
}
