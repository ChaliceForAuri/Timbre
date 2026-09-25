import CryptoKit
import Foundation
import Security

/// Why an update was refused. Every case leaves the installed app untouched.
nonisolated public enum UpdateFailure: LocalizedError, Equatable {
    case feed(String)
    case download(String)
    case sizeMismatch
    case hashMismatch
    case unpackFailed
    case notTimbre(String)
    case versionMismatch(expected: String, found: String)
    case cannotReplace(String)

    public var errorDescription: String? {
        switch self {
        case .feed(let why): "Couldn't read the version file: \(why)"
        case .download(let why): "The download failed: \(why)"
        case .sizeMismatch, .hashMismatch:
            "The download doesn't match the published release, so it wasn't installed."
        case .unpackFailed: "The download couldn't be unpacked."
        case .notTimbre(let why):
            "The download isn't a notarized copy of Timbre, so it wasn't installed. (\(why))"
        case .versionMismatch(let expected, let found):
            "The download is version \(found), not \(expected), so it wasn't installed."
        case .cannotReplace(let why): "Timbre couldn't replace itself: \(why)"
        }
    }
}

/// The trust anchor for updates (ADR-0010). The hash proves the download is
/// the file the version file describes; the code signature proves it is
/// Timbre, signed by our team and notarized by Apple — which a compromised
/// website could not forge.
nonisolated enum UpdateVerifier {

    static let teamIdentifier = "WX9L5M4Y9Q"
    static let bundleIdentifier = "dev.hugopretorius.Timbre"

    /// A Developer ID application (the leaf field is Apple's marker for
    /// one), our identifier, our team, and notarized.
    static var requirement: String {
        "anchor apple generic and identifier \"\(bundleIdentifier)\""
            + " and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
            + " and notarized"
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Throws unless `app` is strictly valid and satisfies `requirement`.
    static func verifySignature(of app: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateFailure.notTimbre("no readable signature")
        }
        var compiled: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess,
            let compiled
        else { throw UpdateFailure.notTimbre("requirement did not compile") }

        let flags = SecCSFlags(
            rawValue: UInt32(kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        )
        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(code, flags, compiled, &error)
        guard status == errSecSuccess else {
            let reason = error?.takeRetainedValue().localizedDescription ?? "status \(status)"
            throw UpdateFailure.notTimbre(reason)
        }
    }

    /// Whether a copy of Timbre can replace itself: only a notarized release
    /// can. A build from Xcode or `install.sh` is signed for development and
    /// is pointed at the download page instead.
    static func isRelease(_ app: URL) -> Bool {
        (try? verifySignature(of: app)) != nil
    }
}
