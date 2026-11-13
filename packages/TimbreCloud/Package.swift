// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001).
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// The Library through the user's own iCloud (GDR-0023, decision 1; ADR-0017):
// CloudKit's private database, Apple's daemons moving the records, the
// binary still making no request. CloudKit exists on all three platforms,
// so that is the package's reach (ADR-0015).
let package = Package(
    name: "TimbreCloud",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "TimbreCloud", targets: ["TimbreCloud"])
    ],
    dependencies: [
        .package(path: "../TimbreCore")
    ],
    targets: [
        .target(
            name: "TimbreCloud",
            dependencies: ["TimbreCore"],
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreCloudTests",
            dependencies: ["TimbreCloud"],
            swiftSettings: concurrencySettings
        ),
    ]
)
