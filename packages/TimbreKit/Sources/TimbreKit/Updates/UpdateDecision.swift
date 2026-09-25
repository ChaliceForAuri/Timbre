import Foundation

/// What a fetched version file means for the copy of Timbre that fetched it.
/// Pure, so every rule about when to offer an update is testable.
nonisolated enum UpdateDecision: Equatable {
    case upToDate
    case available(AppRelease)
    /// Newer, but this Mac's macOS is too old for it.
    case needsNewerMacOS(AppRelease)
    /// The file is not something this version will act on.
    case unusable(String)

    static func decide(
        _ release: AppRelease,
        currentVersion: String,
        currentBuild: Int,
        system: OperatingSystemVersion,
        feed: URL
    ) -> UpdateDecision {
        guard let latest = VersionNumber(release.version), let current = VersionNumber(currentVersion),
            let minimum = VersionNumber(release.minimumSystemVersion)
        else { return .unusable("The version file couldn't be read.") }

        // The download must come from where the version file came from: one
        // host, the one the privacy page names (GDR-0013).
        guard isAllowedDownload(release.url, feed: feed) else {
            return .unusable("The update's download address isn't on Timbre's own site.")
        }

        let newer = latest > current || (latest == current && release.build > currentBuild)
        guard newer else { return .upToDate }
        return VersionNumber(system) >= minimum ? .available(release) : .needsNewerMacOS(release)
    }

    /// Same scheme and host as the feed; https in the app, file:// only in
    /// the evaluation harness, which points the feed at a local folder.
    static func isAllowedDownload(_ url: URL, feed: URL) -> Bool {
        guard let scheme = url.scheme, scheme == feed.scheme, scheme == "https" || scheme == "file" else {
            return false
        }
        return url.host == feed.host
    }
}

/// When a check is due, for the opt-in daily check.
nonisolated enum UpdateSchedule {
    /// A little under a day, so a Mac woken at the same time each morning
    /// checks each morning rather than every other.
    static let interval: TimeInterval = 23 * 60 * 60

    static func isDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= interval || now < lastChecked
    }
}
