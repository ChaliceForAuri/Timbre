import SpokeKit
import SwiftUI

struct SettingsView: View {
    let controller: DictationController
    @State private var newTerm = ""
    @State private var capturedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spoke")
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

            captureSection
        }
        .padding(20)
        .frame(width: 420, height: 620)
        .onAppear { capturedCount = controller.capturedDictationCount() }
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
                Writes what you say, and what Spoke pasted, to a file on this \
                Mac. Nothing is uploaded. Useful for improving the cleanup; \
                leave it off if you'd rather Spoke kept no record.
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
