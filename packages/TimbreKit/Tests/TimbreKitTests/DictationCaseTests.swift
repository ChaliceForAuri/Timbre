import Foundation
import Testing

@testable import TimbreKit

struct DictationCaseTests {

    @Test func spokenIsOptionalAndOmittedFromJSONWhenAbsent() throws {
        let json = #"{"id":"x","transcript":"timber kit"}"#
        let decoded = try JSONDecoder().decode(DictationCase.self, from: Data(json.utf8))
        #expect(decoded.spoken == nil)

        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        #expect(!encoded.contains("spoken"))
    }

    @Test func spokenCarriesTheSentenceToSynthesize() throws {
        let json = #"{"id":"x","transcript":"timber kit","spoken":"TimbreKit"}"#
        let decoded = try JSONDecoder().decode(DictationCase.self, from: Data(json.utf8))
        #expect(decoded.spoken == "TimbreKit")
    }
}
