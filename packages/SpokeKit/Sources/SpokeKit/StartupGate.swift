/// Decides whether Spoke can start, and what to tell the user when it can't.
///
/// Extracted because the *ordering* of permission requests is a real decision
/// with a real failure mode, not glue. Spoke originally checked Accessibility
/// first and returned early, which meant that on a Mac without Accessibility
/// granted the microphone was never requested at all — and macOS lists an app
/// under Privacy & Security › Microphone only once it has asked. The user saw
/// no prompt, found no entry to toggle, and had no way to tell why.
///
/// So: ask for everything, then report everything missing at once. A user
/// should learn the full cost of getting started in one trip to System
/// Settings, not discover it one relaunch at a time.
nonisolated enum StartupGate {

    /// What macOS told us about each permission.
    struct Permissions: Equatable {
        var microphone: Bool
        var accessibility: Bool
    }

    /// `nil` when Spoke can start. Otherwise the message to show.
    static func blockingMessage(for permissions: Permissions) -> String? {
        var missing: [String] = []
        if !permissions.microphone { missing.append("Microphone") }
        if !permissions.accessibility { missing.append("Accessibility") }
        guard !missing.isEmpty else { return nil }

        let list = missing.joined(separator: " and ")

        // Accessibility is only read at launch, so it always needs a relaunch.
        // Microphone alone does not — saying so avoids sending the user on a
        // restart they don't need.
        let relaunch =
            permissions.accessibility
            ? "" : " Then quit and reopen Spoke — Accessibility is only read at launch."

        return "Grant \(list) in System Settings › Privacy & Security.\(relaunch)"
    }
}
