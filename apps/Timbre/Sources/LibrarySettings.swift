import SwiftUI
import TimbreKit
import UniformTypeIdentifiers

/// Settings › Library (GDR-0023): one store, five kinds, with a kind filter
/// and a search; the word of the day and its notification; the profile;
/// export and import. Shown in full, so nothing rewrites text or answers a
/// question in secret.
struct LibrarySettings: View {
    let controller: DictationController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                WordOfTheDaySection(wordOfTheDay: controller.wordOfTheDay)
                Divider()
                PracticeSection(library: controller.library)
                Divider()
                EntriesSection(library: controller.library)
                Divider()
                ProfileSection(library: controller.library)
                Divider()
                CloudSection(controller: controller)
                Divider()
                ExportSection(library: controller.library)
                Divider()
                AboutTheWordsSection()
            }
            .padding(24)
        }
    }
}

// MARK: - The word of the day

private struct WordOfTheDaySection: View {
    @Bindable var wordOfTheDay: WordOfTheDay
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Word of the day")
                    .font(.headline)
                Spacer()
                if let card = wordOfTheDay.card {
                    Button(card.term) {
                        NSApp.activate()
                        openWindow(id: WordCardWindow.id)
                    }
                    .buttonStyle(.link)
                } else {
                    Text("Nothing due")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Text(
                "The word in your Library that has faded furthest, chosen at the start of each day. Saying it "
                    + "in a dictation counts as meeting it. Facts on the card say where they came from."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Toggle("Tell me each morning", isOn: $wordOfTheDay.notifies)
            if wordOfTheDay.notifies {
                HStack(spacing: 10) {
                    DatePicker("At", selection: time, displayedComponents: .hourAndMinute)
                        .frame(width: 120)
                    switch wordOfTheDay.notificationState {
                    case .needsPermission:
                        Button("Allow notifications…") { Task { await wordOfTheDay.requestNotifications() } }
                    case .denied:
                        Text("Notifications are off for Timbre in System Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .on, .off:
                        EmptyView()
                    }
                }
                Text("A local notification from this Mac. Nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: wordOfTheDay.notificationHour, minute: wordOfTheDay.notificationMinute,
                    second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                wordOfTheDay.notificationHour = parts.hour ?? 9
                wordOfTheDay.notificationMinute = parts.minute ?? 0
            }
        )
    }
}

// MARK: - Entries

private struct EntriesSection: View {
    let library: Library
    @State private var query = LibraryQuery()
    @State private var editing: LibraryEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Library")
                .font(.headline)
            Text(
                "Words the model should prefer, phrases to practise, your own acronyms (they answer explain "
                    + "first), spellings fix corrected, and corrections — what Timbre heard against what you meant, "
                    + "applied before the model. Nothing here leaves your Mac."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Picker("Kind", selection: $query.kind) {
                    Text("All").tag(EntryKind?.none)
                    ForEach(EntryKind.allCases, id: \.self) { kind in
                        Text(kind.plural).tag(EntryKind?.some(kind))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 130)
                TextField("Search", text: $query.search)
                    .textFieldStyle(.roundedBorder)
            }

            AddEntryRow(library: library, kind: query.kind ?? .word)

            let shown = query.apply(to: library.entries)
            RowList(
                isEmpty: shown.isEmpty,
                emptyText: library.entries.isEmpty ? "Nothing here yet." : "Nothing matches."
            ) {
                ForEach(shown) { entry in
                    EntryRow(entry: entry, library: library) { editing = entry }
                }
            }

            HStack {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .sheet(item: $editing) { entry in
            EditEntrySheet(entry: entry, library: library)
        }
    }

    private var summary: String {
        let count = library.entries.count
        let due = library.entries.filter { $0.kind.isLearnable && library.isDue($0.id) }.count
        let noun = count == 1 ? "entry" : "entries"
        return due == 0 ? "\(count) \(noun)." : "\(count) \(noun) · \(due) due."
    }
}

extension EntryKind {
    var plural: String {
        switch self {
        case .word: "Words"
        case .acronym: "Acronyms"
        case .phrase: "Phrases"
        case .spelling: "Spellings"
        case .correction: "Corrections"
        }
    }
}

private struct EntryRow: View {
    let entry: LibraryEntry
    let library: Library
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if entry.kind == .correction, let heard = entry.heard {
                        Text(heard).foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(entry.term)
                    if entry.kind == .spelling, let heard = entry.heard {
                        Text("not \(heard)").font(.caption).foregroundStyle(.tertiary)
                    }
                    SourceTag(text: entry.kind.rawValue)
                }
                if let meaning = entry.meaning {
                    Text(meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(provenance)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if entry.kind.isLearnable, !library.history(of: entry.id).isEmpty {
                StrengthBar(strength: library.strength(of: entry.id))
            }
            Button(action: edit) { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .help("Edit")
            RemoveButton { library.forget(entryID: entry.id) }
        }
    }

    private var provenance: String {
        var parts: [String] = []
        switch entry.source.how {
        case .dictated: parts.append("Dictated")
        case .typed: parts.append("Added")
        case .explained: parts.append("Explained")
        case .corrected: parts.append("Corrected")
        case .bundled: parts.append("From a list")
        case .imported: parts.append("Imported")
        }
        if let app = entry.source.app { parts.append("in \(app)") }
        parts.append("on \(entry.source.date.formatted(.dateTime.day().month(.abbreviated)))")
        if entry.source.device != .mac { parts.append("· \(entry.source.device.rawValue)") }
        return parts.joined(separator: " ")
    }
}

/// One row that adds whatever kind is selected: a word or phrase with an
/// optional meaning, an acronym with its meaning, a spelling with the
/// misspelling, a correction heard → meant.
private struct AddEntryRow: View {
    let library: Library
    let kind: EntryKind
    @State private var left = ""
    @State private var right = ""

    var body: some View {
        HStack {
            TextField(leftPrompt, text: $left)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            if kind == .correction || kind == .spelling {
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
            }
            TextField(rightPrompt, text: $right)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            Button(actionTitle, action: submit)
                .disabled(!canSubmit)
        }
    }

    private var leftPrompt: String {
        switch kind {
        case .word: "A word"
        case .acronym: "Term, e.g. ADR"
        case .phrase: "A phrase"
        case .spelling: "The misspelling"
        case .correction: "Timbre heard"
        }
    }

    private var rightPrompt: String {
        switch kind {
        case .word, .phrase: "What it means (optional)"
        case .acronym: "What it means"
        case .spelling: "The correct spelling"
        case .correction: "You meant"
        }
    }

    private var actionTitle: String {
        switch kind {
        case .word, .phrase: "Add"
        case .acronym: "Define"
        case .spelling: "Add"
        case .correction: "Teach"
        }
    }

    private var canSubmit: Bool {
        let hasLeft = !left.trimmingCharacters(in: .whitespaces).isEmpty
        let hasRight = !right.trimmingCharacters(in: .whitespaces).isEmpty
        switch kind {
        case .word, .phrase: return hasLeft
        case .acronym, .spelling, .correction: return hasLeft && hasRight
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let source = Provenance(device: .mac, date: Date(), how: .typed)
        let entry: LibraryEntry?
        switch kind {
        case .word, .phrase:
            entry = LibraryEntry(kind: kind, term: left, meaning: right.isEmpty ? nil : right, source: source)
        case .acronym:
            entry = LibraryEntry(kind: .acronym, term: left, meaning: right, source: source)
        case .spelling:
            entry = LibraryEntry(kind: .spelling, term: right, heard: left, source: source)
        case .correction:
            entry = LibraryEntry(kind: .correction, term: right, heard: left, source: source)
        }
        guard let entry else { return }
        if kind == .correction {
            library.teach(heard: left, meant: right)
        } else {
            library.upsert(entry)
        }
        left = ""
        right = ""
    }
}

/// Edits the fields a user can change: term, the other side, meaning,
/// example, tags. The kind and the history are what they are.
private struct EditEntrySheet: View {
    let entry: LibraryEntry
    let library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var heard = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var tags = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit \(entry.kind.rawValue)")
                .font(.headline)
            Form {
                TextField(entry.kind == .correction ? "You meant" : "Term", text: $term)
                if entry.kind == .correction || entry.kind == .spelling {
                    TextField(entry.kind == .correction ? "Timbre heard" : "The misspelling", text: $heard)
                }
                TextField("Meaning", text: $meaning, axis: .vertical)
                TextField("Example sentence", text: $example, axis: .vertical)
                TextField("Tags, comma-separated", text: $tags)
            }
            .formStyle(.columns)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            term = entry.term
            heard = entry.heard ?? ""
            meaning = entry.meaning ?? ""
            example = entry.example ?? ""
            tags = entry.tags.joined(separator: ", ")
        }
    }

    private func save() {
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        guard
            let updated = LibraryEntry(
                kind: entry.kind, term: term, heard: heard.isEmpty ? nil : heard,
                meaning: meaning.isEmpty ? nil : meaning,
                example: example.isEmpty ? nil : example, tags: tagList, source: entry.source)
        else { return }
        if updated.id != entry.id {
            // The term that names the entry changed: the old one goes, with its tombstone.
            library.forget(entryID: entry.id)
        }
        library.upsert(updated)
        dismiss()
    }
}

// MARK: - Profile

private struct ProfileSection: View {
    let library: Library
    @State private var industries = ""
    @State private var role = ""
    @State private var language = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About you")
                .font(.headline)
            Text(
                "Your field chooses the word lists, and will make explain right for your reader. Lives in "
                    + "your Library; synced only if you turn iCloud on, never sent to us."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Field").foregroundStyle(.secondary)
                    TextField("software, product", text: $industries).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Role").foregroundStyle(.secondary)
                    TextField("engineer", text: $role).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("First language").foregroundStyle(.secondary)
                    TextField("English", text: $language).textFieldStyle(.roundedBorder)
                }
            }
            .font(.callout)
        }
        .onAppear(perform: load)
        .onChange(of: industries) { _, _ in save() }
        .onChange(of: role) { _, _ in save() }
        .onChange(of: language) { _, _ in save() }
    }

    private func load() {
        industries = library.profile.industries.joined(separator: ", ")
        role = library.profile.role ?? ""
        language = library.profile.firstLanguage ?? ""
    }

    private func save() {
        let list = industries.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        let profile = Profile(
            industries: list, role: role.isEmpty ? nil : role,
            firstLanguage: language.isEmpty ? nil : language)
        if profile != library.profile { library.profile = profile }
    }
}

// MARK: - Export and import

private struct ExportSection: View {
    let library: Library
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your file")
                .font(.headline)
            Text(
                "The whole Library as one JSON file: every entry and its history. Import merges — nothing "
                    + "is overwritten, and a word forgotten here stays forgotten."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Export…", action: export)
                Button("Import…", action: importFile)
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Library.defaultFileURL])
                }
                .buttonStyle(.link)
                Spacer()
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func export() {
        NSApp.activate()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Timbre Library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try library.export().write(to: url, options: .atomic)
            message = "Exported \(library.entries.count) entries."
        } catch {
            message = error.localizedDescription
        }
    }

    private func importFile() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try library.importDocument(Data(contentsOf: url))
            message = added.entries == 0 ? "Nothing new in that file." : "Added \(added.entries) entries."
        } catch Library.ImportError.newerSchema {
            message = "That file was written by a newer Timbre."
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Practice, the streak and the week

/// The private kind of game (GDR-0027): a streak of days met or practised,
/// what this week held, and the five words most worth a minute.
private struct PracticeSection: View {
    let library: Library
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Practice")
                    .font(.headline)
                Spacer()
                Button("Practise now…") { PracticeWindow.open(openWindow) }
            }
            Text(
                "Spell it, Say it, Explain it — spoken, scored on this Mac. A word comes up as it fades, and "
                    + "saying today's word in a dictation counts as meeting it."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            let now = Date()
            let streak = Streaks.current(in: library.events, on: now)
            let week = Streaks.week(in: library.events, ending: now)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow {
                    Text("Streak").foregroundStyle(.secondary)
                    Text(streak == 1 ? "1 day" : "\(streak) days")
                    Text("best \(Streaks.best(in: library.events))").foregroundStyle(.tertiary)
                }
                GridRow {
                    Text("This week").foregroundStyle(.secondary)
                    Text("\(week.met) met · \(week.practised) practised")
                    Text(week.practised == 0 ? "" : "\(week.passed) right").foregroundStyle(.tertiary)
                }
            }
            .font(.callout.monospacedDigit())

            let weakest = Streaks.weakest(among: library.entries, events: library.events, at: now)
            if !weakest.isEmpty {
                Text("Most worth a minute")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                ForEach(weakest, id: \.entry.id) { item in
                    HStack {
                        Text(item.entry.term).font(.callout)
                        Spacer()
                        StrengthBar(strength: item.strength)
                    }
                }
            }
        }
    }
}

// MARK: - iCloud

/// The one boundary, described exactly (GDR-0010, GDR-0023 decision 1): the
/// Library can sync through the user's own iCloud, off by default, and
/// Timbre still makes no network request — macOS's own daemon does the
/// syncing. Dictations never go.
private struct CloudSection: View {
    let controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("iCloud")
                .font(.headline)
            Toggle(
                "Sync my Library through iCloud",
                isOn: Binding(
                    get: { controller.syncsThroughICloud },
                    set: { controller.syncsThroughICloud = $0 }
                )
            )
            Text(
                "Your words, meanings and practice history, in your own iCloud account, so your iPhone, Watch and "
                    + "other Macs have the same Library. Timbre sends nothing itself: macOS's iCloud daemon does the "
                    + "syncing. Never a dictation, a capture or a usage count. Encrypted in transit and on Apple's "
                    + "servers; not yet end-to-end encrypted."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if controller.syncsThroughICloud {
                    Button("Sync Now") { Task { await controller.cloud.syncNow() } }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                Link(
                    "About Advanced Data Protection",
                    destination: URL(string: "https://support.apple.com/en-us/102651")!
                )
                .font(.caption)
            }
        }
    }

    private var status: String {
        switch controller.cloud.status {
        case .off: "Off. Your Library stays on this Mac; Export in the section below is the other way out."
        case .starting: "Starting…"
        case .syncing: "Syncing…"
        case .upToDate(let date):
            date.map { "Up to date, last fetched \($0.formatted(.relative(presentation: .named)))." }
                ?? "Up to date."
        case .unavailable(let reason): reason
        }
    }
}

// MARK: - About the words

/// Where the facts on a card come from, and under what terms (GDR-0028):
/// the bundled lists are a Wiktionary extract, CC BY-SA 4.0, attributed
/// here and on every card that shows them.
private struct AboutTheWordsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About the words")
                .font(.headline)
            if let attribution = BundledLists.attribution {
                Text(attribution)
                    .font(.callout)
            } else {
                Text("No bundled lists in this build yet; the word of the day comes from your Library alone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(
                "Definitions, pronunciations and origins labelled Wiktionary are from the English Wiktionary, by its "
                    + "contributors, under the Creative Commons Attribution-ShareAlike 4.0 licence. Lines labelled "
                    + "\"written by the model\" are the on-device model's and are never presented as facts. Apple's "
                    + "dictionary, where shown, is Apple's."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Link("Wiktionary", destination: URL(string: "https://en.wiktionary.org/")!)
                Link(
                    "CC BY-SA 4.0",
                    destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                Link(
                    "The extract and its script",
                    destination: URL(
                        string:
                            "https://github.com/ChaliceForAuri/Timbre/blob/main/packages/TimbreCore/LICENSE-DATA.md"
                    )!)
            }
            .font(.caption)
        }
    }
}
