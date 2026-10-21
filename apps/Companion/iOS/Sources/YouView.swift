import SwiftUI
import TimbreCloud
import TimbreCore

/// About you, your file, and what never leaves the phone.
struct YouView: View {
    let model: CompanionModel
    @State private var industries = ""
    @State private var role = ""
    @State private var language = ""
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Field, e.g. software, product", text: $industries)
                    TextField("Role", text: $role)
                    TextField("First language", text: $language)
                } header: {
                    Text("About you")
                } footer: {
                    Text("Your field chooses the word lists, and will make explain right for your reader.")
                }

                Section {
                    Toggle(
                        "Sync through iCloud",
                        isOn: Binding(
                            get: { model.syncsThroughICloud }, set: { model.syncsThroughICloud = $0 }))
                    LabeledContent("Status", value: cloudStatus)
                    if model.syncsThroughICloud {
                        Button("Sync now") { Task { await model.cloud.syncNow() } }
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text(
                        "Your words, meanings and practice history in your own iCloud, so your Mac and Watch have the same Library. Timbre sends nothing itself; iOS's iCloud daemon does the syncing. Never a dictation. End-to-end encrypted with Advanced Data Protection."
                    )
                }

                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share your Library", systemImage: "square.and.arrow.up")
                        }
                    }
                    LabeledContent("Entries", value: model.library.entries.count.formatted())
                } header: {
                    Text("Your file")
                } footer: {
                    Text(
                        "The whole Library as one JSON file: every entry and its history. Import it on a Mac from Settings › Library."
                    )
                }

                Section {
                    Text(
                        BundledLists.attribution
                            ?? "No bundled lists in this build yet; the word of the day comes from your Library alone."
                    )
                    Link(
                        "Wiktionary, CC BY-SA 4.0",
                        destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                } header: {
                    Text("About the words")
                } footer: {
                    Text(
                        "Definitions, pronunciations and origins labelled Wiktionary are from the English Wiktionary, by its contributors, under CC BY-SA 4.0. Lines labelled \"written by the model\" are the on-device model's and are never presented as facts."
                    )
                }

                Section {
                    LabeledContent(
                        "Apple Intelligence",
                        value: model.modelAvailability.isReady
                            ? "Available" : (model.modelAvailability.reason ?? "Unavailable"))
                    LabeledContent("Speech model", value: model.speechReady ? "Ready" : "Preparing…")
                } header: {
                    Text("On this iPhone")
                } footer: {
                    Text(
                        "Speech recognition, the example sentence and the drills run on-device. Timbre sends nothing about you anywhere: no account, no telemetry. Your Library syncs only through your own iCloud, when you turn that on."
                    )
                }
            }
            .navigationTitle("You")
            .onAppear(perform: load)
            .onChange(of: industries) { _, _ in save() }
            .onChange(of: role) { _, _ in save() }
            .onChange(of: language) { _, _ in save() }
        }
    }

    private func load() {
        industries = model.library.profile.industries.joined(separator: ", ")
        role = model.library.profile.role ?? ""
        language = model.library.profile.firstLanguage ?? ""
        refreshExport()
    }

    private func save() {
        let list = industries.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        let profile = Profile(
            industries: list, role: role.isEmpty ? nil : role,
            firstLanguage: language.isEmpty ? nil : language)
        if profile != model.library.profile {
            model.library.profile = profile
            refreshExport()
        }
    }

    /// Written fresh on each visit, so what is shared is what is there.
    private func refreshExport() {
        let url = URL(filePath: NSTemporaryDirectory()).appending(path: "Timbre Library.json")
        if let data = try? model.library.export(), (try? data.write(to: url, options: .atomic)) != nil {
            exportURL = url
        }
    }
}

extension YouView {
    fileprivate var cloudStatus: String {
        switch model.cloud.status {
        case .off: "Off"
        case .starting: "Starting…"
        case .syncing: "Syncing…"
        case .upToDate(let date):
            date.map { "Up to date, \($0.formatted(.relative(presentation: .named)))" } ?? "Up to date"
        case .unavailable(let reason): reason
        }
    }
}
