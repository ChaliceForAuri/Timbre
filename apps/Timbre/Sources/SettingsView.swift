import SwiftUI
import TimbreKit

struct SettingsView: View {
    let controller: DictationController
    @State private var newTerm = ""
    @State private var capturedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timbre")
                .font(.title2.bold())

            Text(controller.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Text("Your Vocabulary")
                .font(.headline)

            Text("Names, jargon, and product terms the model should prefer. This never leaves your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add a term", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTerm)
                Button("Add", action: addTerm)
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(controller.vocabulary, id: \.self) { term in
                    HStack {
                        Text(term)
                        Spacer()
                        Button {
                            controller.removeFromVocabulary(term)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 160)

            Spacer()

            Divider()

            readingSection

            Divider()

            captureSection
        }
        .padding(20)
        .frame(width: 440, height: 760)
        .onAppear { capturedCount = controller.capturedDictationCount() }
    }

    /// Read-aloud status. Its whole job is the compact-voice warning:
    /// macOS ships only compact voices by default, and a user who never
    /// learns that Enhanced voices exist concludes the feature is broken.
    private var readingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading Aloud")
                .font(.headline)

            Text(
                "Select text anywhere, then tap left Option to hear it. "
                    + "Tap again to speed up; hold to stop."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let voice = controller.readingVoiceName {
                HStack(spacing: 6) {
                    Text("Voice: \(voice)")
                        .font(.caption)
                    if controller.readingVoiceIsCompact {
                        Text("basic quality")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.18), in: Capsule())
                    }
                }
            }

            if controller.readingVoiceIsCompact {
                Text(
                    "Your Mac only has basic voices installed. The Enhanced and "
                        + "Premium voices are free downloads and sound far better — "
                        + "Timbre picks the best one automatically once you add it."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Open Spoken Content settings…") {
                    let url = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent"
                    )
                    if let url { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.link)

                Text("System Settings › Accessibility › Spoken Content › System Voice › Manage Voices…")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    /// Opt-in recording of real dictations, for tuning the polisher against
    /// speech nobody had to write by hand. Deliberately explicit about what it
    /// writes and where — see GDR-0004.
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Save my dictations for tuning", isOn: capture)
                .font(.headline)

            Text(
                """
                Writes what you say, and what Timbre pasted, to a file on this \
                Mac. Nothing is uploaded. Useful for improving the cleanup; \
                leave it off if you'd rather Timbre kept no record.
                """
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if controller.isCapturingDictations || capturedCount > 0 {
                HStack {
                    Text("\(capturedCount) saved")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([controller.captureFileURL])
                    }
                    .disabled(capturedCount == 0)

                    Button("Delete All", role: .destructive) {
                        controller.deleteCapturedDictations()
                        capturedCount = 0
                    }
                    .disabled(capturedCount == 0)
                }
                .buttonStyle(.link)
            }
        }
    }

    private var capture: Binding<Bool> {
        Binding(
            get: { controller.isCapturingDictations },
            set: { newValue in
                controller.isCapturingDictations = newValue
                capturedCount = controller.capturedDictationCount()
            }
        )
    }

    private func addTerm() {
        controller.addToVocabulary(newTerm)
        newTerm = ""
    }
}
