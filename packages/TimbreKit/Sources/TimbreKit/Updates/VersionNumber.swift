import Foundation

/// A dotted version number, compared numerically and padded with zeros:
/// "0.10" is newer than "0.9", and "0.3" equals "0.3.0".
nonisolated struct VersionNumber: Comparable {

    let components: [Int]

    init?(_ string: String) {
        let parts = string.trimmingCharacters(in: .whitespaces)
            .split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 4 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        components = numbers
    }

    init(_ system: OperatingSystemVersion) {
        components = [system.majorVersion, system.minorVersion, system.patchVersion]
    }

    private static func ordering(_ lhs: VersionNumber, _ rhs: VersionNumber) -> Int {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }

    static func < (lhs: VersionNumber, rhs: VersionNumber) -> Bool { ordering(lhs, rhs) < 0 }
    static func == (lhs: VersionNumber, rhs: VersionNumber) -> Bool { ordering(lhs, rhs) == 0 }
}
