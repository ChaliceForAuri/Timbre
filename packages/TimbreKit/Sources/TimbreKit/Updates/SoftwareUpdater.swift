import AppKit
import Foundation
import Observation

/// Timbre's update check (GDR-0013, ADR-0010).
///
/// Off by default. A fresh install makes no network requests; the only one
/// Timbre can ever make is fetching `appcast.json` from its own website —
/// when the user chooses *Check for Updates…*, or once a day if they turn
/// that on. The request carries nothing: an ephemeral session, no cookies,
/// no cache, and a User-Agent of just "Timbre". Installing downloads the zip
/// the file names, from the same host, and only after the user clicks.
///
/// A second app-facing type alongside `DictationController`, deliberately:
/// updating the app is not part of the dictation pipeline (ADR-0010).
@Observable
public final class SoftwareUpdater {

    public nonisolated enum State: Equatable, Sendable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case needsNewerMacOS(AppRelease)
        case installing(AppRelease)
        case failed(String)
    }

    public static let productionFeed = URL(string: "https://timbre.hugopretorius.dev/appcast.json")!
    public static let downloadPage = URL(string: "https://timbre.hugopretorius.dev/download")!

    public private(set) var state: State = .idle
    public private(set) var lastChecked: Date?

    /// The opt-in daily check. Off until the user turns it on.
    public var checksAutomatically: Bool {
        didSet {
            defaults.set(checksAutomatically, forKey: Self.automaticKey)
            scheduleAutomaticChecks()
        }
    }

    /// `CFBundleShortVersionString` of the running copy.
    public let currentVersion: String

    /// Whether this copy can replace itself. Only a notarized release can; a
    /// development build is pointed at the download page instead.
    public let canInstallInPlace: Bool

    private static let automaticKey = "checksForUpdatesAutomatically"
    private static let lastCheckedKey = "lastUpdateCheck"

    private let feed: URL
    private let bundle: Bundle
    private let defaults: UserDefaults
    private let currentBuild: Int
    private let session: URLSession
    private var automaticTask: Task<Void, Never>?

    public init(
        feed: URL = SoftwareUpdater.productionFeed, bundle: Bundle = .main, defaults: UserDefaults = .standard
    ) {
        self.feed = feed
        self.bundle = bundle
        self.defaults = defaults
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        currentBuild = Int(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
        canInstallInPlace = UpdateVerifier.isRelease(bundle.bundleURL)
        checksAutomatically = defaults.bool(forKey: Self.automaticKey)
        lastChecked = defaults.object(forKey: Self.lastCheckedKey) as? Date
        session = Self.makeSession()
    }

    /// Begins the daily check if the user has turned it on.
    public func start() {
        scheduleAutomaticChecks()
    }

    /// Fetches the version file now and returns what it means.
    @discardableResult
    public func checkNow() async -> State {
        if case .installing = state { return state }
        state = .checking
        do {
            let (data, response) = try await session.data(from: feed)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdateFailure.feed("HTTP \(http.statusCode)")
            }
            let appcast = try JSONDecoder().decode(Appcast.self, from: data)
            let now = Date()
            lastChecked = now
            defaults.set(now, forKey: Self.lastCheckedKey)

            switch UpdateDecision.decide(
                appcast.latest,
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                system: ProcessInfo.processInfo.operatingSystemVersion,
                feed: feed
            ) {
            case .upToDate: state = .upToDate
            case .available(let release): state = .available(release)
            case .needsNewerMacOS(let release): state = .needsNewerMacOS(release)
            case .unusable(let why): state = .failed(why)
            }
        } catch let failure as UpdateFailure {
            state = .failed(failure.localizedDescription)
        } catch is DecodingError {
            state = .failed(UpdateFailure.feed("unexpected format").localizedDescription)
        } catch {
            state = .failed(UpdateFailure.feed(error.localizedDescription).localizedDescription)
        }
        return state
    }

    /// Downloads, verifies and installs the available release, then relaunches.
    /// On any failure the installed app is untouched and `state` says why.
    public func installAndRelaunch() async {
        guard case .available(let release) = state else { return }
        guard canInstallInPlace else {
            NSWorkspace.shared.open(Self.downloadPage)
            return
        }

        state = .installing(release)
        let verified: URL
        do {
            verified = try await UpdateInstaller.prepare(release, using: session)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        do {
            let installed = try UpdateInstaller.replace(bundle.bundleURL, with: verified)
            try UpdateInstaller.relaunch(installed)
            NSApplication.shared.terminate(nil)
        } catch {
            // Verified but not installable here (a read-only Applications
            // folder, say): hand it over rather than lose the download.
            handOver(verified, release: release, because: error)
        }
    }

    private func handOver(_ app: URL, release: AppRelease, because error: Error) {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = downloads.appending(path: "Timbre \(release.version).app")
        try? FileManager.default.removeItem(at: destination)
        if (try? FileManager.default.moveItem(at: app, to: destination)) != nil {
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            state = .failed(
                "\(error.localizedDescription) The verified update is in Downloads — drag it to Applications."
            )
        } else {
            state = .failed(error.localizedDescription)
        }
    }

    private func scheduleAutomaticChecks() {
        automaticTask?.cancel()
        automaticTask = nil
        guard checksAutomatically else { return }
        automaticTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if UpdateSchedule.isDue(lastChecked: self.lastChecked, now: Date()) {
                    await self.checkNow()
                }
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    /// Nothing persists and nothing identifies: no cookies, no cache, no
    /// stored credentials, and a User-Agent that names the app and nothing
    /// about the Mac.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpAdditionalHeaders = ["User-Agent": "Timbre"]
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }
}
