// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001),
// duplicated by copy: there is no third package for shared settings.
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// The platform-neutral package (ADR-0013): the Library, the to-do parser,
// strength, the daily pick, the drill checks. Foundation and Observation
// only, so the Mac, the iPhone and the Watch all import it.
let package = Package(
    name: "TimbreCore",
    platforms: [.macOS(.v26), .iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "TimbreCore", targets: ["TimbreCore"])
    ],
    targets: [
        .target(
            name: "TimbreCore",
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreCoreTests",
            dependencies: ["TimbreCore"],
            swiftSettings: concurrencySettings
        ),
    ]
)
