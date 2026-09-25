import SwiftUI
import TimbreKit

/// Settings, in four tabs. It was one tall column until the dictionary grew
/// a third list; a window taller than a 13-inch screen is not a settings
/// window.
struct SettingsView: View {
    let controller: DictationController
    let updater: SoftwareUpdater

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings(controller: controller, updater: updater)
            }
            Tab("Dictionary", systemImage: "character.book.closed") {
                DictionarySettings(controller: controller)
            }
            Tab("Reading", systemImage: "speaker.wave.2") {
                ReadingSettings(controller: controller)
            }
            Tab("Privacy", systemImage: "hand.raised") {
                PrivacySettings(controller: controller)
            }
        }
        .frame(width: 540, height: 600)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    let controller: DictationController
    let updater: SoftwareUpdater

    var body: some View {
        ScrollView {
            content
                .padding(24)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timbre")
                    .font(.title2.bold())
                Text(controller.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Three keys")
                .font(.headline)

            ShortcutRow(
                keys: "hold right ⌥",
                title: "Dictate",
                detail: "Speak, release. Cleaned-up text lands wherever your cursor is."
            )
            ShortcutRow(
                keys: "tap left ⌥",
                title: "Read aloud",
                detail: "Reads the selection. Tap again to speed up; hold to stop."
            )
            ShortcutRow(
                keys: "hold right ⌘",
                title: "Fix · explain · shorten · plain",
                detail: "On a selection. Say one of the four, or say nothing to fix. "
                    + "Explain shows a card; the others replace the text, and ⌘Z puts it back. "
                    + "Plain strips corporate filler and says what the text actually says."
            )
            ShortcutRow(
                keys: "hold right ⌘",
                title: "Add a to-do",
                detail: "With nothing selected, say it — \"call the dentist Thursday\" — and it lands in "
                    + "Reminders. Tap left ⌥ with nothing selected to hear the list."
            )

            Divider()

            TypingSection(controller: controller)

            Divider()

            UsageSection(controller: controller)

            Divider()

            TodosSection(controller: controller)

            Divider()

            UpdatesSection(updater: updater)
        }
    }
}

/// Words as you speak, or words on release (GDR-0018).
private struct TypingSection: View {
    let controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("While you talk")
                .font(.headline)
            Toggle(
                "Type as I speak",
                isOn: Binding(
                    get: { controller.typesAsYouSpeak },
                    set: { controller.typesAsYouSpeak = $0 }
                )
            )
            Text(
                "Words appear in the app as they are confirmed, and the cleanup replaces them when you let go. "
                    + "Off keeps every word in the pill until you release the key — handy on a shared screen."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// What Timbre has done on this Mac. Counted here, never transmitted — the
/// counter Tidy shows, minus any suggestion that anyone else can see it.
private struct UsageSection: View {
    let controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Mac, so far")
                .font(.headline)
            if controller.usage.allTime.isEmpty {
                Text("Nothing yet. Hold right ⌥ and say something.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                    GridRow {
                        Text("").frame(width: 0)
                        Text("This week").font(.caption).foregroundStyle(.secondary)
                        Text("All time").font(.caption).foregroundStyle(.secondary)
                    }
                    row("Words dictated", \.words)
                    row("Dictations", \.dictations)
                    row("Commands", \.commands)
                    row("To-dos", \.todos)
                    row("Read aloud", \.readings)
                }
                .font(.callout.monospacedDigit())
                HStack {
                    Text("Stored in this Mac's preferences and nowhere else.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset", role: .destructive) { controller.resetUsage() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        }
    }

    private func row(_ label: String, _ key: KeyPath<UsageLedger.Counts, Int>) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(controller.usage.thisWeek[keyPath: key].formatted())
            Text(controller.usage.allTime[keyPath: key].formatted())
        }
    }
}

/// Where spoken to-dos go (GDR-0016): the Reminders permission and the list.
private struct TodosSection: View {
    let controller: DictationController
    @State private var lists: [(id: String, title: String, account: String)] = []
    @State private var chosen: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To-dos")
                .font(.headline)
            Text(
                "Spoken to-dos go to Apple's Reminders, so they are on your iPhone and your other Macs "
                    + "through your own iCloud. Timbre still sends nothing anywhere; macOS does the syncing."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            switch controller.remindersAccess {
            case .granted:
                Picker("List", selection: $chosen) {
                    Text("Timbre (created if needed)").tag("")
                    ForEach(lists, id: \.id) { list in
                        Text("\(list.title) — \(list.account)").tag(list.id)
                    }
                }
                .onChange(of: chosen) { _, value in
                    controller.chosenTodoListIdentifier = value.isEmpty ? nil : value
                }
            case .notAsked:
                Button("Allow Reminders access…") {
                    Task {
                        await controller.requestRemindersAccess()
                        reload()
                    }
                }
            case .denied:
                Text("Reminders access is off for Timbre.")
                    .font(.caption)
                Button("Open Privacy & Security › Reminders") {
                    let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")
                    if let url { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.link)
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        lists = controller.availableTodoLists
        chosen = controller.chosenTodoListIdentifier ?? ""
    }
}

/// The update check, described exactly (GDR-0013): what it fetches, from
/// where, and that it is the only request Timbre can make.
private struct UpdatesSection: View {
    @Bindable var updater: SoftwareUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Updates")
                    .font(.headline)
                Spacer()
                Text("Timbre \(updater.currentVersion)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Toggle("Check for updates once a day", isOn: $updater.checksAutomatically)

            Text(
                "Off by default. When on, Timbre fetches one small version file from "
                    + "timbre.hugopretorius.dev — no identifier, no cookie, nothing about you or your words. "
                    + "It is the only network request Timbre can make. Installing an update asks first."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if case .available(let release) = updater.state {
                    Button("Install \(release.version)…") { UpdatePrompt.offer(release, updater: updater) }
                }
                Button("Check Now") { UpdatePrompt.checkAndReport(updater) }
                    .disabled(updater.state == .checking)
            }
        }
    }

    private var status: String {
        switch updater.state {
        case .idle:
            updater.lastChecked.map { "Last checked \($0.formatted(.relative(presentation: .named)))." }
                ?? "Not checked yet."
        case .checking: "Checking…"
        case .upToDate: "Up to date."
        case .available(let release): "Timbre \(release.version) is available."
        case .needsNewerMacOS(let release): "\(release.version) needs macOS \(release.minimumSystemVersion)."
        case .installing(let release): "Installing \(release.version)…"
        case .failed(let message): message
        }
    }
}

private struct ShortcutRow: View {
    let keys: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(keys)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .frame(width: 118, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Dictionary

/// The personal dictionary: words, corrections, definitions. Shown in full so
/// nothing rewrites text, or answers a question, in secret.
private struct DictionarySettings: View {
    let controller: DictationController
    @State private var newTerm = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                vocabulary

                DictionarySection(
                    title: "Corrections",
                    blurb: "When Timbre keeps hearing a phrase wrong, teach it what you meant. "
                        + "Applied to every dictation, exactly as written.",
                    leftPrompt: "Timbre heard",
                    rightPrompt: "You meant",
                    actionTitle: "Teach",
                    rows: controller.corrections.map { Row(id: $0.id, left: $0.heard, right: $0.meant) },
                    add: { controller.teachCorrection(heard: $0, meant: $1) },
                    remove: { row in
                        if let match = controller.corrections.first(where: { $0.id == row.id }) {
                            controller.forgetCorrection(match)
                        }
                    }
                )

                DictionarySection(
                    title: "Definitions",
                    blurb: "Your own acronyms and terms. When you hold right ⌘ and say explain, "
                        + "these answer first — the on-device model does not know your jargon.",
                    leftPrompt: "Term, e.g. ADR",
                    rightPrompt: "What it means",
                    actionTitle: "Define",
                    rows: controller.acronyms.map { Row(id: $0.id, left: $0.term, right: $0.meaning) },
                    add: { controller.defineAcronym(term: $0, meaning: $1) },
                    remove: { row in
                        if let match = controller.acronyms.first(where: { $0.id == row.id }) {
                            controller.forgetAcronym(match)
                        }
                    }
                )
            }
            .padding(24)
        }
    }

    private var vocabulary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vocabulary")
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

            RowList(isEmpty: controller.vocabulary.isEmpty) {
                ForEach(controller.vocabulary, id: \.self) { term in
                    HStack {
                        Text(term)
                        Spacer()
                        RemoveButton { controller.removeFromVocabulary(term) }
                    }
                }
            }
        }
    }

    private func addTerm() {
        controller.addToVocabulary(newTerm)
        newTerm = ""
    }
}

/// One displayed pair, whatever it is a pair of.
private struct Row: Identifiable {
    let id: String
    let left: String
    let right: String
}

private struct DictionarySection: View {
    let title: String
    let blurb: String
    let leftPrompt: String
    let rightPrompt: String
    let actionTitle: String
    let rows: [Row]
    let add: (String, String) -> Bool
    let remove: (Row) -> Void

    @State private var left = ""
    @State private var right = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField(leftPrompt, text: $left)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField(rightPrompt, text: $right)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
                Button(actionTitle, action: submit)
                    .disabled(!canSubmit)
            }

            RowList(isEmpty: rows.isEmpty) {
                ForEach(rows) { row in
                    HStack(spacing: 6) {
                        Text(row.left)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(row.right)
                        Spacer()
                        RemoveButton { remove(row) }
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !left.trimmingCharacters(in: .whitespaces).isEmpty
            && !right.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard add(left, right) else { return }
        left = ""
        right = ""
    }
}

/// Rows in a quiet box, or a line saying there are none. Not a `List`: three
/// scrolling lists inside a scrolling tab fight over the scroll wheel.
private struct RowList<Content: View>: View {
    let isEmpty: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEmpty {
                Text("Nothing here yet.")
                    .foregroundStyle(.tertiary)
            } else {
                content
            }
        }
        .font(.callout)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
    }
}

// MARK: - Reading

/// Read-aloud status. Its whole job is the compact-voice warning: macOS ships
/// only compact voices by default, and a user who never learns that Enhanced
/// voices exist concludes the feature is broken.
private struct ReadingSettings: View {
    let controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reading Aloud")
                .font(.headline)

            Text(
                "Select text anywhere, then tap left Option to hear it. Tap again to speed up; hold to stop."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let voice = controller.readingVoiceName {
                HStack(spacing: 6) {
                    Text("Voice: \(voice)")
                        .font(.callout)
                    if controller.readingVoiceIsCompact {
                        Text("basic quality")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.18), in: Capsule())
                    }
                }
                .padding(.top, 6)
            }

            if controller.readingVoiceIsCompact {
                Text(
                    "Your Mac only has basic voices installed. The Enhanced and "
                        + "Premium voices are free downloads and sound far better — "
                        + "Timbre picks the best one automatically once you add it."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Privacy

/// Opt-in recording of real dictations, for tuning the polisher against
/// speech nobody had to write by hand. Deliberately explicit about what it
/// writes and where — see GDR-0004.
private struct PrivacySettings: View {
    let controller: DictationController
    @State private var capturedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing leaves this Mac")
                .font(.headline)
            Text(
                "Speech recognition, cleanup, commands and reading all run on-device. "
                    + "Timbre sends nothing about you anywhere: no telemetry, no crash reports. The only "
                    + "network request it can make is the update check in General, which is off unless you turn it on."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 6)

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
            .fixedSize(horizontal: false, vertical: true)

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

            Spacer()
        }
        .padding(24)
        .onAppear { capturedCount = controller.capturedDictationCount() }
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
}
