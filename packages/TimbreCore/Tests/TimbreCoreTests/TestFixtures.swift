import Foundation

/// `packages/TimbreCore/Fixtures`, found from this file so the tests run
/// from any working directory.
nonisolated enum Fixtures {
    static var directory: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures", directoryHint: .isDirectory)
    }

    static func url(_ name: String) -> URL {
        directory.appending(path: name)
    }
}
