import Foundation
import TimbreCore

/// The example writer's corpus (GDR-0027, property 4): a word, its meaning,
/// the reader's field, and the guardrail every draft must pass. The model is
/// stochastic in principle and greedy in practice, so the harness repeats.
public struct ExampleCorpus: Codable, Sendable {

    public struct Case: Codable, Sendable {
        public let id: String
        public let note: String?
        public let term: String
        public let meaning: String?
        public let industry: String?
        /// Apple's guardrail refuses this one; the case stays so the refusal
        /// is visible, and a draft appearing would be news.
        public let expectRefusal: Bool?
    }

    public let cases: [Case]

    public static func load(from url: URL) throws -> ExampleCorpus {
        try JSONDecoder().decode(ExampleCorpus.self, from: Data(contentsOf: url))
    }
}
