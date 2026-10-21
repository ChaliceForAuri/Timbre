import Testing

@testable import TimbreCore

struct MetDetectorTests {

    @Test func wholeWordIgnoringCase() {
        #expect(MetDetector.contains("ephemeral", in: "An Ephemeral thing."))
        #expect(!MetDetector.contains("ephemeral", in: "ephemerally"))
        #expect(!MetDetector.contains("ephemeral", in: ""))
    }

    @Test func phrasesTolerateWhitespace() {
        #expect(MetDetector.contains("table stakes", in: "that is table   stakes now"))
        #expect(!MetDetector.contains("table stakes", in: "the table's stakes"))
    }
}
