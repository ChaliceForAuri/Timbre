// swift-tools-version: 6.2
import PackageDescription

// The same language mode and concurrency defaults as TimbreKit (ADR-0001).
let concurrencySettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

// Speech in and out (ADR-0015): microphone capture, on-device transcription
// with SpeechAnalyzer, reading aloud with the best installed voice. The Mac
// and the iPhone share it; the Watch has no SpeechAnalyzer and does not.
let package = Package(
    name: "TimbreSpeech",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "TimbreSpeech", targets: ["TimbreSpeech"])
    ],
    targets: [
        .target(
            name: "TimbreSpeech",
            swiftSettings: concurrencySettings
        ),
        .testTarget(
            name: "TimbreSpeechTests",
            dependencies: ["TimbreSpeech"],
            swiftSettings: concurrencySettings
        ),
    ]
)
