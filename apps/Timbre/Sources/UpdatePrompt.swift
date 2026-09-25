import AppKit
import TimbreKit

/// The update dialogs. Only ever shown because the user chose something —
/// *Check for Updates…* or *Install…* — so activating the app is correct
/// here, as it is for Settings. A background check never pops anything up;
/// it only adds an item to the menu.
@MainActor
enum UpdatePrompt {

    static func checkAndReport(_ updater: SoftwareUpdater) {
        NSApp.activate()
        Task {
            switch await updater.checkNow() {
            case .available(let release):
                offer(release, updater: updater)
            case .upToDate:
                inform("You're up to date", "Timbre \(updater.currentVersion) is the newest version.")
            case .needsNewerMacOS(let release):
                inform(
                    "Timbre \(release.version) needs macOS \(release.minimumSystemVersion)",
                    "You have Timbre \(updater.currentVersion), the newest version for this Mac."
                )
            case .failed(let message):
                inform("Couldn't check for updates", message)
            case .idle, .checking, .installing:
                break
            }
        }
    }

    static func offer(_ release: AppRelease, updater: SoftwareUpdater) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Timbre \(release.version) is available"
        alert.informativeText = "You have \(updater.currentVersion).\n\n\(release.notes.prefix(900))"
        alert.addButton(withTitle: updater.canInstallInPlace ? "Install and Relaunch" : "Open Download Page")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task {
            await updater.installAndRelaunch()
            // Only reached if the install did not relaunch.
            if case .failed(let message) = updater.state {
                inform("The update wasn't installed", message)
            }
        }
    }

    private static func inform(_ title: String, _ detail: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}
