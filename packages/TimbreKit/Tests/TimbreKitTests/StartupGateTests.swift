import Testing

@testable import TimbreKit

@Suite("StartupGate")
struct StartupGateTests {

    @Test("Nothing blocks when both permissions are granted")
    func passesWhenGranted() {
        let permissions = StartupGate.Permissions(microphone: true, accessibility: true)
        #expect(StartupGate.blockingMessage(for: permissions) == nil)
    }

    /// The regression that started this: a missing Accessibility grant used to
    /// stop the microphone ever being requested, so the user was told about
    /// one problem while a second stayed invisible.
    @Test("Both missing permissions are reported together")
    func reportsBothAtOnce() throws {
        let permissions = StartupGate.Permissions(microphone: false, accessibility: false)
        let message = try #require(StartupGate.blockingMessage(for: permissions))
        #expect(message.contains("Microphone"))
        #expect(message.contains("Accessibility"))
    }

    @Test("Only Accessibility asks for a relaunch")
    func relaunchOnlyForAccessibility() throws {
        let micOnly = StartupGate.Permissions(microphone: false, accessibility: true)
        let message = try #require(StartupGate.blockingMessage(for: micOnly))
        #expect(message.contains("Microphone"))
        #expect(!message.contains("Accessibility"))
        #expect(!message.contains("quit and reopen"))

        let axOnly = StartupGate.Permissions(microphone: true, accessibility: false)
        let axMessage = try #require(StartupGate.blockingMessage(for: axOnly))
        #expect(axMessage.contains("quit and reopen"))
    }
}
