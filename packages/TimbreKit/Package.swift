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
    name: "TimbreKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TimbreKit", targets: ["TimbreKit"]),
        .executable(name: "timbre-eval", targets: ["TimbreEval"]),
    ],
    targets: [
        .target(
            name: "TimbreKit",
            swiftSettings: concurrencySettings
        ),
        .executableTarget(
            name: "TimbreEval",
            dependencies: ["TimbreKit"],
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreKitTests",
            dependencies: ["TimbreKit"],
            swiftSettings: concurrencySettings
        ),
    ]
)
