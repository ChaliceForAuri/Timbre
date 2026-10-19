// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001).
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// Apple's on-device model, where it runs (ADR-0015): the card's example
// writer today, the drills' judges next. Every prompt here is greedy,
// guarded by a check in TimbreCore, and measured by the harness.
let package = Package(
    name: "TimbreModel",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "TimbreModel", targets: ["TimbreModel"])
    ],
    dependencies: [
        .package(path: "../TimbreCore")
    ],
    targets: [
        .target(
            name: "TimbreModel",
            dependencies: ["TimbreCore"],
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreModelTests",
            dependencies: ["TimbreModel"],
            swiftSettings: concurrencySettings
        ),
    ]
)
