import Foundation

/// One right-⌘ hold, as a decision: when does what was said become a
/// command, and exactly once (GDR-0014).
///
/// Command mode acts the moment a live result contains a command word rather
/// than waiting for the key to come up. That creates three ways to run the
/// same command twice — a live result, the key coming up, and a late final
/// result arriving while the release is being handled — and this type is
/// what makes sure only the first of them counts.
nonisolated struct CommandHold: Equatable {

    enum Phase: Equatable {
        /// Listening; a live result can still fire a command.
        case listening
        /// The key came up first; the final transcript decides.
        case releasing
        /// A command was chosen. Nothing else about this hold matters.
        case decided(VoiceCommand)
    }

    /// What the key coming up means.
    enum Release: Equatable {
        /// A command already fired while the key was held.
        case alreadyHandled
        case run(VoiceCommand)
        /// Words that are not a command. Shown back to the user; nothing runs.
        case unrecognised(String)
    }

    private(set) var phase: Phase = .listening

    /// Whether a shortcut detected mid-hold should still cancel it. Once a
    /// command is running, the user's other keys are their own business.
    var acceptsInterruption: Bool { phase == .listening }

    var hasDecided: Bool {
        if case .decided = phase { return true }
        return false
    }

    /// A live result arrived. Returns the command to run *now*, at most once.
    mutating func heard(_ transcript: String) -> VoiceCommand? {
        guard phase == .listening, let command = VoiceCommand.recognizedWhileSpeaking(in: transcript)
        else { return nil }
        phase = .decided(command)
        return command
    }

    /// The key came up before any live result fired. Stops live results from
    /// firing while the final transcript is being fetched.
    mutating func beginRelease() -> Release? {
        if hasDecided { return .alreadyHandled }
        phase = .releasing
        return nil
    }

    /// The final transcript after the key came up. Silence means fix.
    mutating func resolve(finalTranscript: String) -> Release {
        if hasDecided { return .alreadyHandled }
        guard let command = VoiceCommand.parse(finalTranscript) else {
            return .unrecognised(finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        phase = .decided(command)
        return .run(command)
    }
}
