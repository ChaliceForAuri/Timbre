// swift-tools-version: 6.2
import PackageDescription

// Swift 6 language mode with the Xcode 26 template's concurrency defaults:
// everything is MainActor unless it opts out. See ADR-0001.
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "SpokeKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SpokeKit", targets: ["SpokeKit"])
    ],
    targets: [
        .target(
            name: "SpokeKit",
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "SpokeKitTests",
            dependencies: ["SpokeKit"],
            swiftSettings: concurrencySettings
        ),
    ]
)
