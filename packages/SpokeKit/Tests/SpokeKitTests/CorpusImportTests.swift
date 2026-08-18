import Foundation
import Testing

@testable import SpokeKit

@Suite("CorpusImport")
struct CorpusImportTests {

    private let log = """
        {"id":"a","date":"2026-08-18T10:00:00Z","appContext":"Slack","transcript":"so um ship it","polished":"Ship it."}
        {"id":"b","date":"2026-08-18T10:01:00Z","transcript":"","polished":""}
        {"id":"c","date":"2026-08-18T10:02:00Z","transcript":"the deploy went out","polished":"The deploy went out."}
        """

    @Test("Decodes JSON Lines")
    func decodesLines() {
        #expect(CorpusImport.records(fromJSONLines: log).count == 3)
    }

    /// A menu bar app can be force-quit mid-write, so a truncated final line
    /// must not cost the records already on disk.
    @Test("A malformed line is skipped, not fatal")
    func skipsMalformedLines() {
        let truncated = log + "\n{\"id\":\"d\",\"transcr"
        #expect(CorpusImport.records(fromJSONLines: truncated).count == 3)
    }

    @Test("Empty transcripts are dropped — they could never fail a check")
    func dropsEmptyTranscripts() {
        let corpus = CorpusImport.corpus(from: CorpusImport.records(fromJSONLines: log))
        #expect(corpus.cases.count == 2)
        #expect(corpus.cases.allSatisfy { !$0.transcript.isEmpty })
    }

    @Test("Cases carry context and the polished text for reference")
    func preservesContext() throws {
        let corpus = CorpusImport.corpus(from: CorpusImport.records(fromJSONLines: log))
        let first = try #require(corpus.cases.first)
        #expect(first.id == "real-001")
        #expect(first.appContext == "Slack")
        #expect(first.note?.contains("Ship it.") == true)
        // Left for the user: only they know what had to survive.
        #expect(first.required.isEmpty)
        #expect(first.forbidden.isEmpty)
    }
}
