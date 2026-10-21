// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001).
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// Watch to phone (ADR-0015, GDR-0029): a to-do said on the wrist, queued
// until the iPhone can file it in Reminders, over WatchConnectivity — Apple's
// transport between the user's own devices. The framework exists only on
// iOS and watchOS, so that is the package's reach.
let package = Package(
    name: "TimbreRelay",
    platforms: [.iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "TimbreRelay", targets: ["TimbreRelay"])
    ],
    dependencies: [
        .package(path: "../TimbreCore")
    ],
    targets: [
        .target(
            name: "TimbreRelay",
            dependencies: ["TimbreCore"],
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreRelayTests",
            dependencies: ["TimbreRelay"],
            swiftSettings: concurrencySettings
        ),
    ]
)
