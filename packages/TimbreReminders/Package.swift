// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001).
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// The Timbre list in Apple's Reminders (GDR-0016), through EventKit, which
// every one of the three platforms has (ADR-0015). The to-do key on the
// wrist runs this with no phone and no model (GDR-0026).
let package = Package(
    name: "TimbreReminders",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "TimbreReminders", targets: ["TimbreReminders"])
    ],
    dependencies: [
        .package(path: "../TimbreCore")
    ],
    targets: [
        .target(
            name: "TimbreReminders",
            dependencies: ["TimbreCore"],
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreRemindersTests",
            dependencies: ["TimbreReminders"],
            swiftSettings: concurrencySettings
        ),
    ]
)
