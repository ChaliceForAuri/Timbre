import SpokeKit
import SwiftUI

struct SettingsView: View {
    let controller: DictationController
    @State private var newTerm = ""

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
        }
        .padding(20)
        .frame(width: 420, height: 460)
    }

    private func addTerm() {
        controller.addToVocabulary(newTerm)
        newTerm = ""
    }
}
