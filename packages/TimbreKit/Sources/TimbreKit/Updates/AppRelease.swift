import Foundation

/// The version file Timbre checks: `appcast.json` on the website (GDR-0013).
/// Written by `tools/release.sh`, never by hand.
nonisolated public struct Appcast: Codable, Sendable, Equatable {
    public let latest: AppRelease
}

/// One published version of Timbre.
nonisolated public struct AppRelease: Codable, Sendable, Equatable, Identifiable {
    /// `CFBundleShortVersionString`, e.g. "0.3.1".
    public let version: String
    /// `CFBundleVersion`: breaks ties between two builds of one version.
    public let build: Int
    /// The oldest macOS the release runs on, e.g. "26.0".
    public let minimumSystemVersion: String
    /// The notarized zip. Must be on the same host as the feed.
    public let url: URL
    /// Lowercase hex SHA-256 of the zip.
    public let sha256: String
    /// Size of the zip in bytes.
    public let size: Int
    /// ISO date the release was published.
    public let published: String
    /// What changed, as plain text.
    public let notes: String

    public var id: String { "\(version)+\(build)" }
}
