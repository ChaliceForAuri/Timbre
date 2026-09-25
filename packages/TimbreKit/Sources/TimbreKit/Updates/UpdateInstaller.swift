import Foundation

/// Download, check, unpack, verify, replace, relaunch (ADR-0010). Each step
/// either succeeds or throws before the installed app is touched; only the
/// last one changes anything.
nonisolated enum UpdateInstaller {

    /// Downloads `release`, checks its size and hash, unpacks it into a fresh
    /// temporary folder and verifies the app inside. Returns that app.
    @concurrent
    static func prepare(_ release: AppRelease, using session: URLSession) async throws -> URL {
        let downloaded: URL
        do {
            let (location, response) = try await session.download(from: release.url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdateFailure.download("HTTP \(http.statusCode)")
            }
            downloaded = location
        } catch let failure as UpdateFailure {
            throw failure
        } catch {
            throw UpdateFailure.download(error.localizedDescription)
        }

        let data = try Data(contentsOf: downloaded)
        guard data.count == release.size else { throw UpdateFailure.sizeMismatch }
        guard UpdateVerifier.sha256Hex(of: data) == release.sha256.lowercased() else {
            throw UpdateFailure.hashMismatch
        }

        let folder = FileManager.default.temporaryDirectory.appending(
            path: "timbre-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appending(path: "Timbre.zip")
        try data.write(to: zip)
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path]) == 0 else {
            throw UpdateFailure.unpackFailed
        }

        let app = folder.appending(path: "Timbre.app")
        guard FileManager.default.fileExists(atPath: app.path) else { throw UpdateFailure.unpackFailed }
        try UpdateVerifier.verifySignature(of: app)

        let found = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard found == release.version else {
            throw UpdateFailure.versionMismatch(expected: release.version, found: found ?? "unknown")
        }
        return app
    }

    /// Swaps the verified app in for the installed one, in one filesystem
    /// operation. Returns where the new app now lives.
    static func replace(_ installed: URL, with verified: URL) throws -> URL {
        do {
            return try FileManager.default.replaceItemAt(installed, withItemAt: verified) ?? installed
        } catch {
            throw UpdateFailure.cannotReplace(error.localizedDescription)
        }
    }

    /// Opens `app` once this process has exited. The caller terminates.
    ///
    /// A detached shell waits on our process ID, then asks Launch Services to
    /// open the new bundle. The path travels as an argument, never inside the
    /// script, so no path can be read as a command.
    static func relaunch(_ app: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let waiter = Process()
        waiter.executableURL = URL(filePath: "/bin/sh")
        waiter.arguments = [
            "-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
            app.path,
        ]
        try waiter.run()
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
