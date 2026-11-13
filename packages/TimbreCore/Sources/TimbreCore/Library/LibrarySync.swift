import Foundation

/// The one door sync comes through (GDR-0023, decision 1). The Library
/// pushes what it added and pulls what others added; merging is the
/// Library's own, pure rule (`LibraryMerge`). The CloudKit implementation
/// lives where that framework is, never here; an account-backed one could
/// stand behind the same door one day, with its own record.
public protocol LibrarySync: Sendable {
    func push(entries: [LibraryEntry], events: [LibraryEvent]) async throws
    func pull() async throws -> (entries: [LibraryEntry], events: [LibraryEvent])
}
