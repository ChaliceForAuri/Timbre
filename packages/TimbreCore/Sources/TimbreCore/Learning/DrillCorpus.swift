import Foundation

/// The drills' corpus (GDR-0023, decision 5): what was said for a word, and
/// what the check must make of it. The deterministic halves — Say it's
/// guardrail, Explain it's word check — are run by the tests; the model's
/// verdicts by `timbre-eval --drills`, repeated.
nonisolated public struct DrillCorpus: Codable, Sendable {

    public struct Case: Codable, Sendable {
        public let id: String
        public let note: String?
        public let drill: Drill
        public let term: String
        public let meaning: String?
        /// What the recogniser returned.
        public let spoken: String
        /// What the deterministic half must conclude: "passed", "failed",
        /// or "unsure" (Explain it hands over to the judge).
        public let expect: String
        /// For the model's half: what the judge should say, when asked.
        public let judge: String?
    }

    public struct Outcome: Sendable {
        public let id: String
        public let expected: String
        public let got: String
        public let detail: String
        public var held: Bool { expected == got }
    }

    public let cases: [Case]

    public static func load(from url: URL) throws -> DrillCorpus {
        try JSONDecoder().decode(DrillCorpus.self, from: Data(contentsOf: url))
    }

    /// The deterministic half of every case.
    public func run() -> [Outcome] {
        cases.map { testCase in
            switch testCase.drill {
            case .spellIt:
                let verdict = SpellCheck.check(testCase.term, against: testCase.spoken)
                return Outcome(
                    id: testCase.id, expected: testCase.expect, got: verdict.passed ? "passed" : "failed",
                    detail: "heard \(verdict.heard)")
            case .sayIt:
                let failures = SayItGuardrail.failures(in: testCase.spoken, for: testCase.term)
                return Outcome(
                    id: testCase.id, expected: testCase.expect, got: failures.isEmpty ? "unsure" : "failed",
                    detail: failures.isEmpty
                        ? "for the judge" : failures.map(\.rawValue).joined(separator: ", "))
            case .explainIt:
                switch ExplainItCheck.check(
                    term: testCase.term, meaning: testCase.meaning ?? "", explanation: testCase.spoken)
                {
                case .passed(let verdict):
                    return Outcome(
                        id: testCase.id, expected: testCase.expect, got: "passed", detail: verdict.reason)
                case .failed(let verdict):
                    return Outcome(
                        id: testCase.id, expected: testCase.expect, got: "failed", detail: verdict.reason)
                case .unsure(let coverage):
                    return Outcome(
                        id: testCase.id, expected: testCase.expect, got: "unsure",
                        detail: "coverage \(Int((coverage * 100).rounded()))%")
                }
            }
        }
    }
}
