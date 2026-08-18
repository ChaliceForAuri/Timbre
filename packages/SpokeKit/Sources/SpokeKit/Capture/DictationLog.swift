import Foundation
import Observation
import os

/// Appends dictations to a local file so they can become evaluation fixtures.
///
/// **Off by default and never automatic.** This writes what the user says to
/// disk in plain text, which is a meaningful thing to do in an app whose whole
/// promise is that nothing leaves the machine (GDR-0001). It stays local, but
/// local is not the same as invisible — so it is opt-in, the file is somewhere
/// the user can find, and Spoke can delete it on request. See GDR-0004.
///
/// JSON Lines rather than one array: appending a line cannot corrupt the
/// records already written, which matters when the writer is a menu bar app
/// that may be force-quit mid-dictation.
@Observable
final class DictationLog {

    private static let defaultsKey = "captureDictations"

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "dev.hugopretorius.Spoke", category: "capture")

    /// Whether new dictations are recorded. Off unless the user turns it on.
    var isCapturing: Bool {
        didSet { defaults.set(isCapturing, forKey: Self.defaultsKey) }
    }

    /// `~/Library/Application Support/Spoke/dictations.jsonl`
    @ObservationIgnored
    private(set) lazy var fileURL: URL = {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(filePath: NSHomeDirectory())
        return base.appending(path: "Spoke", directoryHint: .isDirectory)
            .appending(path: "dictations.jsonl")
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isCapturing = defaults.bool(forKey: Self.defaultsKey)
    }

    /// Appends one record. Failures are logged and swallowed: losing a tuning
    /// fixture must never cost the user their dictation.
    func append(_ record: DictationRecord) {
        guard isCapturing else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            var line = try encoder.encode(record)
            line.append(0x0A)

            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: fileURL, options: .atomic)
            }
        } catch {
            logger.error("could not append dictation record: \(error.localizedDescription)")
        }
    }

    /// Number of records on disk, for the settings screen.
    func recordCount() -> Int {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return 0 }
        return contents.split(separator: "\n").count
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
