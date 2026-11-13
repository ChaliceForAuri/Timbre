import Testing

@testable import TimbreSpeech

struct InputFallbackTests {

    @Test func aSilentBluetoothInputFallsBackAfterTheWait() {
        #expect(
            InputFallback.shouldFallBack(
                inputIsBluetooth: true, heardAudio: false, after: .milliseconds(2500)))
        #expect(InputFallback.shouldFallBack(inputIsBluetooth: true, heardAudio: false, after: .seconds(4)))
    }

    @Test func aWakingHeadsetIsGivenTime() {
        #expect(
            !InputFallback.shouldFallBack(
                inputIsBluetooth: true, heardAudio: false, after: .milliseconds(1800)))
    }

    @Test func aHeadsetThatSpokeIsLeftAlone() {
        #expect(!InputFallback.shouldFallBack(inputIsBluetooth: true, heardAudio: true, after: .seconds(10)))
    }

    @Test func wiredAndBuiltInInputsNeverFallBack() {
        #expect(
            !InputFallback.shouldFallBack(inputIsBluetooth: false, heardAudio: false, after: .seconds(10)))
    }
}
