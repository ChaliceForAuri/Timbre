// Writes the bundled word data (GDR-0028) from a Wiktionary extract and the
// term lists in packages/TimbreCore/Lists. The extract is kaikki.org's
// machine-readable English Wiktionary (one JSON object per line, made with
// wiktextract); this script streams it from stdin, keeps only the terms the
// lists name, and emits one BundledList per list, with the facts a card
// shows — definition, part of speech, IPA, origin — and nothing the model
// could have written. Run on our side, never in the app.
//
//   swift tools/extract-words.swift \
//     --lists packages/TimbreCore/Lists \
//     --out packages/TimbreCore/Sources/TimbreCore/Resources/bundled-words.json \
//     < kaikki.org-dictionary-English.jsonl
//
// Reports how many terms each list found, and prints the ones it did not
// to stderr, so a missing word is a curation decision, not a silent gap.
// The output is a derivative of Wiktionary, CC BY-SA 4.0; see
// packages/TimbreCore/LICENSE-DATA.md.

import Foundation

// MARK: - Arguments

let arguments = Array(CommandLine.arguments.dropFirst())
func value(for flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}
guard let listsPath = value(for: "--lists"), let outPath = value(for: "--out") else {
    FileHandle.standardError.write(Data("usage: extract-words.swift --lists <dir> --out <file> < dump.jsonl\n".utf8))
    exit(64)
}

// MARK: - The lists

struct ListSpec: Decodable {
    let id: String
    let title: String
    let industries: [String]
    let file: String
}

let listsDirectory = URL(filePath: listsPath, directoryHint: .isDirectory)
let specs = try JSONDecoder().decode([ListSpec].self, from: Data(contentsOf: listsDirectory.appending(path: "lists.json")))

/// Terms per list, in curated order; and every wanted term, lowercased, for the one pass.
var termsByList: [String: [String]] = [:]
var wanted: Set<String> = []
for spec in specs {
    let text = try String(contentsOf: listsDirectory.appending(path: spec.file), encoding: .utf8)
    let terms = text.split(separator: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    termsByList[spec.id] = terms
    for term in terms { wanted.insert(term.lowercased()) }
}

// MARK: - One pass over the dump

struct Found {
    var partOfSpeech: String?
    var pronunciation: String?
    var definition: String?
    var origin: String?
    /// Lower is better: a plain sense beats an obsolete one; a noun beats a proper name.
    var rank: Int
}

let acceptablePOS: Set<String> = ["noun", "verb", "adj", "adv", "phrase", "prep_phrase", "intj", "prep", "pron"]
let unwantedTags: Set<String> = ["obsolete", "archaic", "vulgar", "offensive", "dated", "rare", "slang", "dialectal"]
let posNames = ["adj": "adjective", "adv": "adverb", "intj": "interjection", "prep": "preposition", "prep_phrase": "phrase", "pron": "pronoun"]

var found: [String: Found] = [:]
var lines = 0

func sentenceCut(_ text: String, limit: Int) -> String {
    let trimmed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > limit else { return trimmed }
    let head = trimmed.prefix(limit)
    if let end = head.lastIndex(where: { ".;".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 2 {
        return String(head[...end])
    }
    if let space = head.lastIndex(of: " ") { return String(head[..<space]) + "…" }
    return String(head) + "…"
}

while let line = readLine(strippingNewline: true) {
    lines += 1
    // Cheap pre-check before parsing: the word field appears early in each line.
    guard let wordRange = line.range(of: "\"word\": \"") else { continue }
    let afterWord = line[wordRange.upperBound...]
    guard let close = afterWord.firstIndex(of: "\"") else { continue }
    let word = String(afterWord[..<close])
    guard wanted.contains(word.lowercased()) else { continue }
    guard let data = line.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        (object["lang_code"] as? String) == "en",
        let pos = object["pos"] as? String, acceptablePOS.contains(pos)
    else { continue }

    let senses = object["senses"] as? [[String: Any]] ?? []
    var definition: String?
    var rank = 2
    for sense in senses {
        let tags = Set((sense["tags"] as? [String]) ?? [])
        guard let glosses = sense["glosses"] as? [String], let gloss = glosses.last, !gloss.isEmpty else { continue }
        let unwanted = !tags.isDisjoint(with: unwantedTags)
        let candidateRank = unwanted ? 1 : 0
        if definition == nil || candidateRank < rank {
            definition = gloss
            rank = candidateRank
        }
        if rank == 0 { break }
    }
    guard let definition else { continue }

    var pronunciation: String?
    for sound in object["sounds"] as? [[String: Any]] ?? [] {
        guard let ipa = sound["ipa"] as? String else { continue }
        let tags = Set((sound["tags"] as? [String]) ?? [])
        if pronunciation == nil || tags.contains("US") || tags.contains("General-American") {
            pronunciation = ipa
            if tags.contains("US") || tags.contains("General-American") { break }
        }
    }

    let origin = (object["etymology_text"] as? String).map { sentenceCut($0, limit: 240) }
    let partOfSpeech = posNames[pos] ?? pos
    let candidate = Found(
        partOfSpeech: partOfSpeech, pronunciation: pronunciation, definition: sentenceCut(definition, limit: 240),
        origin: origin?.isEmpty == true ? nil : origin, rank: rank)
    let key = word.lowercased()
    if let existing = found[key], existing.rank <= candidate.rank {
        // Keep the first good sense; borrow a pronunciation or origin it lacked.
        var merged = existing
        if merged.pronunciation == nil { merged.pronunciation = candidate.pronunciation }
        if merged.origin == nil { merged.origin = candidate.origin }
        found[key] = merged
    } else {
        found[key] = candidate
    }
}

// MARK: - Output, in the lists' own shape (TimbreCore's BundledList)

struct BundledWordOut: Encodable {
    let term: String
    let partOfSpeech: String?
    let pronunciation: String?
    let definition: String
    let origin: String?
    let parts: String?
}
struct BundledListOut: Encodable {
    let id: String
    let title: String
    let industries: [String]
    let source: String
    let licence: String
    let words: [BundledWordOut]
}

var output: [BundledListOut] = []
var missingReport: [String] = []
for spec in specs {
    let terms = termsByList[spec.id] ?? []
    var words: [BundledWordOut] = []
    var missing: [String] = []
    for term in terms {
        if let hit = found[term.lowercased()], let definition = hit.definition {
            words.append(
                BundledWordOut(
                    term: term, partOfSpeech: hit.partOfSpeech, pronunciation: hit.pronunciation,
                    definition: definition, origin: hit.origin, parts: nil))
        } else {
            missing.append(term)
        }
    }
    output.append(
        BundledListOut(
            id: spec.id, title: spec.title, industries: spec.industries, source: "Wiktionary",
            licence: "CC BY-SA 4.0", words: words))
    print("\(spec.title): \(words.count)/\(terms.count) found")
    if !missing.isEmpty { missingReport.append("\(spec.title): " + missing.joined(separator: ", ")) }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(output).write(to: URL(filePath: outPath), options: .atomic)
print("\(lines) lines read → \(outPath)")
if !missingReport.isEmpty {
    FileHandle.standardError.write(Data(("not in the extract:\n  " + missingReport.joined(separator: "\n  ") + "\n").utf8))
}
