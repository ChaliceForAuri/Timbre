import Foundation
import Testing

@testable import TimbreKit

struct VersionNumberTests {

    @Test func comparesNumericallyNotAlphabetically() {
        #expect(VersionNumber("0.10")! > VersionNumber("0.9")!)
        #expect(VersionNumber("1.0")! > VersionNumber("0.99.9")!)
    }

    @Test func missingComponentsAreZero() {
        #expect(VersionNumber("0.3")! == VersionNumber("0.3.0")!)
        #expect(VersionNumber("26")! == VersionNumber("26.0.0")!)
    }

    @Test func rejectsWhatIsNotAVersion() {
        for text in ["", "v1.0", "1..2", "1.-2", "1.2.3.4.5", "beta"] {
            #expect(VersionNumber(text) == nil)
        }
    }
}

struct UpdateDecisionTests {

    private let feed = URL(string: "https://timbre.hugopretorius.dev/appcast.json")!
    private let tahoe = OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)

    private func release(
        _ version: String,
        build: Int = 5,
        minimum: String = "26.0",
        url: String = "https://timbre.hugopretorius.dev/releases/Timbre-0.3.1.zip"
    ) -> AppRelease {
        AppRelease(
            version: version, build: build, minimumSystemVersion: minimum, url: URL(string: url)!,
            sha256: "00", size: 1, published: "2026-09-24", notes: ""
        )
    }

    @Test func newerIsAvailable() {
        let r = release("0.3.1")
        #expect(
            UpdateDecision.decide(r, currentVersion: "0.3.0", currentBuild: 4, system: tahoe, feed: feed)
                == .available(r))
    }

    @Test func sameOrOlderIsUpToDate() {
        #expect(
            UpdateDecision.decide(
                release("0.3.0", build: 4), currentVersion: "0.3.0", currentBuild: 4, system: tahoe,
                feed: feed) == .upToDate)
        #expect(
            UpdateDecision.decide(
                release("0.2.0"), currentVersion: "0.3.0", currentBuild: 4, system: tahoe, feed: feed)
                == .upToDate)
    }

    /// A rebuilt release of the same version is still an update.
    @Test func aHigherBuildOfTheSameVersionIsAvailable() {
        let r = release("0.3.0", build: 5)
        #expect(
            UpdateDecision.decide(r, currentVersion: "0.3.0", currentBuild: 4, system: tahoe, feed: feed)
                == .available(r))
    }

    @Test func tooNewForThisMac() {
        let r = release("0.4.0", minimum: "27.0")
        #expect(
            UpdateDecision.decide(r, currentVersion: "0.3.0", currentBuild: 4, system: tahoe, feed: feed)
                == .needsNewerMacOS(r))
    }

    /// GDR-0013: one host. A version file pointing anywhere else is refused.
    @Test func aDownloadOffOurSiteIsRefused() {
        for url in [
            "https://github.com/x/Timbre-0.3.1.zip",
            "http://timbre.hugopretorius.dev/releases/Timbre-0.3.1.zip",
            "https://timbre.hugopretorius.dev.evil.example/Timbre.zip",
        ] {
            let decision = UpdateDecision.decide(
                release("0.3.1", url: url), currentVersion: "0.3.0", currentBuild: 4, system: tahoe,
                feed: feed)
            guard case .unusable = decision else {
                Issue.record("accepted \(url)")
                continue
            }
        }
    }

    @Test func theDailyCheckIsDueOncePerDay() {
        let now = Date()
        #expect(UpdateSchedule.isDue(lastChecked: nil, now: now))
        #expect(!UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(-24 * 3600), now: now))
        // A clock set back must not silence checks forever.
        #expect(UpdateSchedule.isDue(lastChecked: now.addingTimeInterval(3600), now: now))
    }

    @Test func theVersionFileDecodes() throws {
        let json = """
            {"latest":{"version":"0.3.0","build":4,"minimumSystemVersion":"26.0",
            "url":"https://timbre.hugopretorius.dev/releases/Timbre-0.3.0.zip",
            "sha256":"ab","size":516808,"published":"2026-09-24","notes":"First."}}
            """
        let appcast = try JSONDecoder().decode(Appcast.self, from: Data(json.utf8))
        #expect(appcast.latest.version == "0.3.0")
        #expect(appcast.latest.size == 516_808)
    }
}

struct UpdateVerifierTests {

    @Test func sha256MatchesAKnownVector() {
        #expect(
            UpdateVerifier.sha256Hex(of: Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    /// Apple-signed, but not Timbre and not our team: must be refused.
    @Test func anAppleSignedToolIsNotTimbre() {
        #expect(throws: UpdateFailure.self) {
            try UpdateVerifier.verifySignature(of: URL(filePath: "/usr/bin/true"))
        }
        #expect(!UpdateVerifier.isRelease(URL(filePath: "/System/Applications/TextEdit.app")))
    }
}
