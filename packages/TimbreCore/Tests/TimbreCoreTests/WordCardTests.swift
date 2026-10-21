import Foundation
import Testing

@testable import TimbreCore

struct WordCardTests {

    private let source = Provenance(device: .mac, date: Date(timeIntervalSince1970: 1_000_000), how: .typed)

    @Test func aLibraryWordShowsYourMeaningThenApplesAndTheModelsExample() {
        let entry = LibraryEntry(kind: .word, term: "ephemeral", meaning: "short-lived", source: source)!
        let pick = DailyPick(
            term: "ephemeral", source: .library(entryID: entry.id, strength: 0.8), why: "why")
        let card = WordCard(
            pick: pick, entry: entry, appleDefinition: ("lasting for a very short time", "əˈfem(ə)rəl"),
            example: "The cache is ephemeral and clears on restart.", metToday: true, strength: 0.7)
        #expect(card.meanings.map(\.source) == [.you, .appleDictionary])
        #expect(card.pronunciation == "əˈfem(ə)rəl")
        #expect(card.example?.source == .model)
        #expect(card.metToday)
        #expect(card.strength == 0.7)
        #expect(card.kind == .word)
        #expect(card.summary == "ephemeral — short-lived")
    }

    @Test func theUsersOwnExampleBeatsTheModels() {
        let entry = LibraryEntry(
            kind: .phrase, term: "table stakes", example: "That is table stakes now.", source: source)!
        let pick = DailyPick(
            term: "table stakes", source: .library(entryID: entry.id, strength: 0.5), why: "why")
        let card = WordCard(pick: pick, entry: entry, example: "ignored")
        #expect(card.example == WordCard.Line("That is table stakes now.", source: .you))
        #expect(card.meanings.isEmpty)
        #expect(card.summary == "Your word for today.")
    }

    @Test func aBundledWordIsTheExtractsFacts() {
        let word = BundledWord(
            term: "tacit", partOfSpeech: "adjective", pronunciation: "ˈtæsɪt",
            definition: "Understood without being said.",
            origin: "From Latin tacitus.")
        let pick = DailyPick(
            term: "tacit", source: .bundled(list: "general", word: word), why: "From the list.")
        let card = WordCard(
            pick: pick, entry: nil, example: "The agreement was tacit, and everyone kept to it.")
        #expect(card.meanings == [WordCard.Line("Understood without being said.", source: .wiktionary)])
        #expect(card.origin?.source == .wiktionary)
        #expect(card.partOfSpeech == "adjective")
        #expect(card.strength == nil)
        #expect(card.kind == nil)
        #expect(card.example?.source == .model)
    }
}
