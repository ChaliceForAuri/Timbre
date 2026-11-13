import Foundation

/// Who the reader is (product map §3): the industries they work in, their
/// role, their first language. Makes explain right for them and chooses the
/// word of the day's lists. Lives in the Library and syncs with it.
nonisolated public struct Profile: Codable, Sendable, Equatable {

    public var industries: [String]
    public var role: String?
    public var firstLanguage: String?

    public init(industries: [String] = [], role: String? = nil, firstLanguage: String? = nil) {
        self.industries = industries
        self.role = role
        self.firstLanguage = firstLanguage
    }

    public static let empty = Profile()
}
