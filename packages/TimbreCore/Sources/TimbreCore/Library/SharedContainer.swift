import Foundation

/// Where the companion keeps the Library and today's snapshot so its widgets
/// and complications can read them: the app group's container when the
/// entitlement is there, the app's own Application Support when it is not
/// (a build without signing). One place, so the app and its extensions
/// never disagree about the path.
nonisolated public enum SharedContainer {

    public static let groupIdentifier = "group.dev.hugopretorius.Timbre"

    public static var directory: URL {
        let base =
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(filePath: NSHomeDirectory())
        return base.appending(path: "Timbre", directoryHint: .isDirectory)
    }

    public static var libraryURL: URL { directory.appending(path: "library.json") }
    public static var snapshotURL: URL { directory.appending(path: "today.json") }
}
