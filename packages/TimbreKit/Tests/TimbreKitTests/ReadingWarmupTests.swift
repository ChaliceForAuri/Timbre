import Testing

@testable import TimbreKit

@Suite("ReadingWarmup")
struct ReadingWarmupTests {

    /// The reported symptom: the first read after a pause loses its opening
    /// words because the Bluetooth output route is still asleep.
    @Test("A cold route gets silence in front of it")
    func coldGetsPreRoll() {
        #expect(ReadingWarmup.preRoll(sinceLastSpeech: nil) == ReadingWarmup.coldPreRoll)
        #expect(ReadingWarmup.preRoll(sinceLastSpeech: .seconds(60)) == ReadingWarmup.coldPreRoll)
    }

    /// Charging every read a fixed pre-roll would make the common case worse
    /// to fix the uncommon one.
    @Test("A warm route starts immediately")
    func warmStartsAtOnce() {
        #expect(ReadingWarmup.preRoll(sinceLastSpeech: .seconds(1)) == 0)
        #expect(ReadingWarmup.preRoll(sinceLastSpeech: .zero) == 0)
    }

    @Test("The boundary favours starting immediately")
    func boundary() {
        #expect(ReadingWarmup.preRoll(sinceLastSpeech: ReadingWarmup.routeStaysWarm) == 0)
    }
}
