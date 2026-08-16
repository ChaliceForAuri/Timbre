import AppKit
import Testing

@testable import SpokeKit

/// Runs against private named pasteboards, never the user's real clipboard.
struct PasteboardSnapshotTests {

    private func withScratchPasteboard(_ body: (NSPasteboard) -> Void) {
        let pasteboard = NSPasteboard(name: .init("SpokeKitTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        body(pasteboard)
    }

    @Test func restoresASingleStringItem() {
        withScratchPasteboard { pasteboard in
            pasteboard.clearContents()
            pasteboard.setString("original", forType: .string)

            let snapshot = PasteboardSnapshot(capturing: pasteboard)

            pasteboard.clearContents()
            pasteboard.setString("dictated text", forType: .string)

            snapshot.restore(to: pasteboard)
            #expect(pasteboard.string(forType: .string) == "original")
        }
    }

    @Test func restoresMultipleItemsInOneWrite() {
        withScratchPasteboard { pasteboard in
            pasteboard.clearContents()
            let first = NSPasteboardItem()
            first.setString("one", forType: .string)
            let second = NSPasteboardItem()
            second.setString("two", forType: .string)
            pasteboard.writeObjects([first, second])

            let snapshot = PasteboardSnapshot(capturing: pasteboard)
            pasteboard.clearContents()
            snapshot.restore(to: pasteboard)

            let strings = pasteboard.pasteboardItems?.compactMap { $0.string(forType: .string) }
            #expect(strings == ["one", "two"])
        }
    }

    @Test func restoresEveryRepresentationOfAnItem() {
        withScratchPasteboard { pasteboard in
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString("plain", forType: .string)
            item.setData(Data("<b>rich</b>".utf8), forType: .html)
            pasteboard.writeObjects([item])

            let snapshot = PasteboardSnapshot(capturing: pasteboard)
            pasteboard.clearContents()
            snapshot.restore(to: pasteboard)

            let restored = pasteboard.pasteboardItems?.first
            #expect(restored?.string(forType: .string) == "plain")
            #expect(restored?.data(forType: .html) == Data("<b>rich</b>".utf8))
        }
    }

    @Test func emptySnapshotRestoresToAnEmptyPasteboard() {
        withScratchPasteboard { pasteboard in
            pasteboard.clearContents()
            let snapshot = PasteboardSnapshot(capturing: pasteboard)
            #expect(snapshot.isEmpty)

            pasteboard.setString("dictated text", forType: .string)
            snapshot.restore(to: pasteboard)
            #expect(pasteboard.pasteboardItems?.isEmpty ?? true)
        }
    }
}
