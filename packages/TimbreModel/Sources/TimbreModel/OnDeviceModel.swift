import FoundationModels

/// Whether Apple's on-device model can run right now, with a reason when it
/// cannot. One answer for every writer and judge here, and for the polisher
/// on the Mac.
public enum OnDeviceModel {

    public static var availability: (isReady: Bool, reason: String?) {
        switch SystemLanguageModel.default.availability {
        case .available:
            return (true, nil)
        case .unavailable(.deviceNotEligible):
            return (false, "This device doesn't support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return (false, "Turn on Apple Intelligence in System Settings.")
        case .unavailable(.modelNotReady):
            return (false, "The on-device model is still downloading. Try again shortly.")
        case .unavailable:
            return (false, "The on-device model is unavailable right now.")
        }
    }
}
