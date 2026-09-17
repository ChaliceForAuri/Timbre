import Testing

@testable import TimbreKit

struct SelectionFrameTests {

    @Test func putsTheWhitespaceBackExactlyAsItCameOff() {
        let frame = SelectionFrame("  \n teh end of the paragraph \n\n")
        #expect(frame.leading == "  \n ")
        #expect(frame.core == "teh end of the paragraph")
        #expect(frame.trailing == " \n\n")
        #expect(frame.wrapping("the end of the paragraph") == "  \n the end of the paragraph \n\n")
    }

    @Test func aTightSelectionHasNoFrame() {
        let frame = SelectionFrame("word")
        #expect(frame.leading.isEmpty && frame.trailing.isEmpty)
        #expect(frame.wrapping("Word") == "Word")
    }

    @Test func whitespaceOnlyHasNoCore() {
        let frame = SelectionFrame(" \n ")
        #expect(frame.core.isEmpty)
        #expect(frame.wrapping("") == " \n ")
    }
}
