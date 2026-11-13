import SwiftUI
import TimbreCore
import TimbreKit

/// Practice on the Mac (GDR-0023, decision 5): the drill today's plan gives
/// each due word, a hold-to-talk button, and the verdict with its reason.
/// Spell it is checked by letters, Say it by the model inside its
/// guardrail, Explain it by the words first and the model only when they
/// cannot tell.
struct PracticeView: View {
    let session: PracticeSession
    @State private var held = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let entry = session.current, let drill = session.drill {
                round(entry, drill: drill)
            } else {
                finished
            }
        }
        .frame(width: 460)
        .padding(24)
        .onAppear { if session.queue.isEmpty { session.begin() } }
        .onDisappear { session.cancel() }
    }

    private func round(_ entry: LibraryEntry, drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(drill.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(session.index + 1) of \(session.queue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            prompt(entry, drill: drill)

            switch session.phase {
            case .verdict(let verdict, let heard):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: verdict.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(verdict.passed ? Color.green : Color.orange)
                        Text(verdict.passed ? "Yes." : "Not quite.")
                            .font(.title3.weight(.semibold))
                    }
                    Text(verdict.reason)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if !heard.isEmpty {
                        Text("You said: \(heard)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(session.remaining > 1 ? "Next" : "Done") { session.next() }
                        .keyboardShortcut(.defaultAction)
                }
            case .idle, .listening, .checking:
                Text(session.live.isEmpty ? (session.phase == .listening ? "Listening…" : " ") : session.live)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                HoldButton(
                    title: session.phase == .checking ? "Checking…" : "Hold and speak",
                    isHeld: held, enabled: session.phase != .checking,
                    onPress: {
                        held = true
                        session.press()
                    },
                    onRelease: {
                        held = false
                        session.release()
                    })
                if let problem = session.problem {
                    Text(problem).font(.caption).foregroundStyle(.orange)
                }
            case .done:
                EmptyView()
            }
        }
    }

    private func prompt(_ entry: LibraryEntry, drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch drill {
            case .spellIt:
                if let meaning = entry.meaning {
                    Text(meaning).font(.title3)
                    Text("Say the word, then spell it.").font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Listen, then say it and spell it.").font(.title3)
                    Button("Hear the word") { session.hearTheWord() }
                }
            case .sayIt:
                Text(entry.term).font(.system(size: 28, weight: .semibold, design: .serif))
                if let meaning = entry.meaning {
                    Text(meaning).font(.callout).foregroundStyle(.secondary)
                }
                Text("Use it in a sentence.").font(.callout).foregroundStyle(.secondary)
            case .explainIt:
                Text(entry.term).font(.system(size: 28, weight: .semibold, design: .serif))
                Text("What does it mean?").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.queue.isEmpty ? "Nothing to practise" : "That is the lot")
                .font(.title3.weight(.semibold))
            Text(
                session.queue.isEmpty
                    ? "Words come here as they fade, weakest first. Teach a few and come back."
                    : "Every due word has had its minute. Tomorrow brings the next."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Button("Again") { session.begin() }
        }
    }
}

/// Press, speak, release, as a button: the Mac's held key for a window.
private struct HoldButton: View {
    let title: String
    let isHeld: Bool
    let enabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        Text(isHeld ? "Listening…" : title)
            .font(.headline)
            .foregroundStyle(isHeld ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isHeld ? Color.accentColor : Color.accentColor.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? 1 : 0.5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if enabled, !isHeld { onPress() } }
                    .onEnded { _ in if isHeld { onRelease() } }
            )
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityHint("Press and hold while you speak")
            .accessibilityAddTraits(.isButton)
    }
}
