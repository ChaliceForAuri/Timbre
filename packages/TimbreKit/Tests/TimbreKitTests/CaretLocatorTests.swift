import Foundation
import Testing

@testable import TimbreKit

/// The Accessibility API reports rects with a top-left origin measured from
/// the top of the primary display; AppKit uses bottom-left. These pin the
/// conversion so "overlay appears on the wrong monitor" can't regress.
struct CaretLocatorTests {

    @Test func convertsTopLeftOriginToBottomLeft() {
        // A 10pt-tall caret 100pt from the top of a 1000pt-tall display
        // sits with its *bottom* edge 890pt up from the bottom.
        let ax = CGRect(x: 250, y: 100, width: 2, height: 10)
        let converted = CaretLocator.convertFromAccessibility(ax, primaryScreenHeight: 1000)
        #expect(converted == NSRect(x: 250, y: 890, width: 2, height: 10))
    }

    @Test func caretAtTheTopOfTheScreen() {
        let ax = CGRect(x: 0, y: 0, width: 1, height: 20)
        let converted = CaretLocator.convertFromAccessibility(ax, primaryScreenHeight: 900)
        #expect(converted.origin.y == 880)
    }

    @Test func caretOnASecondaryDisplayBelowThePrimary() {
        // AX coordinates grow downward, so a display below the primary has
        // y beyond the primary's height; the result is a negative AppKit y.
        let ax = CGRect(x: 500, y: 1200, width: 2, height: 16)
        let converted = CaretLocator.convertFromAccessibility(ax, primaryScreenHeight: 1000)
        #expect(converted.origin.y == -216)
    }

    @Test func roundTripsThroughItself() {
        // Applying the conversion twice returns the original rect — the
        // transform is its own inverse. A cheap invariant over many rects.
        let rects = [
            CGRect(x: 0, y: 0, width: 1, height: 1),
            CGRect(x: 123.5, y: 456.25, width: 2, height: 18),
            CGRect(x: -800, y: 300, width: 3, height: 12),
        ]
        for rect in rects {
            let once = CaretLocator.convertFromAccessibility(rect, primaryScreenHeight: 1080)
            let twice = CaretLocator.convertFromAccessibility(once, primaryScreenHeight: 1080)
            #expect(twice == rect)
        }
    }
}
