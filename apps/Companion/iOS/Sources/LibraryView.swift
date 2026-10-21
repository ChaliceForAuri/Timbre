import SwiftUI
import TimbreCore

/// The Library in your pocket (GDR-0023, decision 2): browse, search, add
/// a word you heard, edit a meaning. The same entries as the Mac.
struct LibraryView: View {
    let model: CompanionModel
    @State private var query = LibraryQuery()
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                Picker("Kind", selection: $query.kind) {
                    Text("All").tag(EntryKind?.none)
                    ForEach(EntryKind.allCases, id: \.self) { kind in
                        Text(kind.plural).tag(EntryKind?.some(kind))
                    }
                }
                .pickerStyle(.menu)

                let shown = query.apply(to: model.library.entries)
                if shown.isEmpty {
                    ContentUnavailableView(
                        model.library.entries.isEmpty ? "Nothing here yet" : "Nothing matches",
                        systemImage: "books.vertical",
                        description: Text(
                            model.library.entries.isEmpty
                                ? "Add a word you heard, or teach one on the Mac." : "Try another word.")
                    )
                } else {
                    ForEach(shown) { entry in
                        NavigationLink(value: entry.id) {
                            EntryRow(entry: entry, library: model.library)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { model.library.forget(entryID: shown[index].id) }
                    }
                }
            }
            .searchable(text: $query.search, prompt: "Search your Library")
            .navigationTitle("Library")
            .navigationDestination(for: String.self) { id in
                if let entry = model.library.entry(id) {
                    EntryDetailView(entry: entry, library: model.library)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add an entry")
                }
            }
            .sheet(isPresented: $adding) {
                AddEntrySheet(library: model.library, kind: query.kind ?? .word)
            }
        }
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

struct EntryRow: View {
    let entry: LibraryEntry
    let library: Library

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if entry.kind == .correction, let heard = entry.heard {
                        Text(heard).foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    Text(entry.term)
                    SourceTag(text: entry.kind.rawValue)
                }
                if let meaning = entry.meaning {
                    Text(meaning).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if entry.kind.isLearnable, !library.history(of: entry.id).isEmpty {
                StrengthBar(strength: library.strength(of: entry.id))
            }
        }
    }
}

/// Edit what a user can change: the term, the other side, the meaning, the
/// example, the tags. The kind and the history are what they are.
struct EntryDetailView: View {
    let entry: LibraryEntry
    let library: Library
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var heard = ""
    @State private var meaning = ""
    @State private var example = ""
    @State private var tags = ""

    var body: some View {
        Form {
            Section {
                TextField(entry.kind == .correction ? "You meant" : "Term", text: $term)
                if entry.kind == .correction || entry.kind == .spelling {
                    TextField(entry.kind == .correction ? "Timbre heard" : "The misspelling", text: $heard)
                }
                TextField("Meaning", text: $meaning, axis: .vertical)
                TextField("Example sentence", text: $example, axis: .vertical)
                TextField("Tags, comma-separated", text: $tags)
            }
            Section("History") {
                let history = library.history(of: entry.id)
                if history.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                } else {
                    if entry.kind.isLearnable {
                        HStack {
                            Text("Strength")
                            Spacer()
                            StrengthBar(strength: library.strength(of: entry.id))
                        }
                    }
                    ForEach(history.suffix(8).reversed(), id: \.id) { event in
                        HStack {
                            Text(event.kind.rawValue.capitalized)
                            if let drill = event.drill { Text(drill.name).foregroundStyle(.secondary) }
                            Spacer()
                            Text(event.date.formatted(.dateTime.day().month(.abbreviated)))
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
            Section {
                Text(provenance).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(entry.term)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            term = entry.term
            heard = entry.heard ?? ""
            meaning = entry.meaning ?? ""
            example = entry.example ?? ""
            tags = entry.tags.joined(separator: ", ")
        }
    }

    private var provenance: String {
        var parts = [entry.source.how.rawValue.capitalized]
        if let app = entry.source.app { parts.append("in \(app)") }
        parts.append("on \(entry.source.date.formatted(.dateTime.day().month(.abbreviated)))")
        parts.append("· \(entry.source.device.rawValue)")
        return parts.joined(separator: " ")
    }

    private func save() {
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
            !$0.isEmpty
        }
        guard
            let updated = LibraryEntry(
                kind: entry.kind, term: term, heard: heard.isEmpty ? nil : heard,
                meaning: meaning.isEmpty ? nil : meaning, example: example.isEmpty ? nil : example,
                tags: tagList, source: entry.source)
        else { return }
        if updated.id != entry.id { library.forget(entryID: entry.id) }
        library.upsert(updated)
        dismiss()
    }
}

/// Adds whatever kind is chosen: a word or phrase with an optional meaning,
/// an acronym with its meaning, a spelling with its misspelling, a
/// correction heard → meant.
struct AddEntrySheet: View {
    let library: Library
    @State var kind: EntryKind
    @Environment(\.dismiss) private var dismiss
    @State private var left = ""
    @State private var right = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Kind", selection: $kind) {
                    ForEach(EntryKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                TextField(leftPrompt, text: $left)
                TextField(rightPrompt, text: $right, axis: .vertical)
            }
            .navigationTitle("Add to the Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle, action: submit).disabled(!canSubmit)
                }
            }
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
        case .acronym: "Define"
        case .correction: "Teach"
        case .word, .phrase, .spelling: "Add"
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
        let source = Provenance(device: .iPhone, date: Date(), how: .typed)
        switch kind {
        case .correction:
            library.teach(heard: left, meant: right)
        case .spelling:
            if let entry = LibraryEntry(kind: .spelling, term: right, heard: left, source: source) {
                library.upsert(entry)
            }
        case .word, .phrase, .acronym:
            if let entry = LibraryEntry(
                kind: kind, term: left, meaning: right.isEmpty ? nil : right, source: source)
            {
                library.upsert(entry)
            }
        }
        dismiss()
    }
}
