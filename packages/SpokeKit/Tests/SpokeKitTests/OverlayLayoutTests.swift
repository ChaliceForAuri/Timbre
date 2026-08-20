import Foundation
import Testing

@testable import SpokeKit

@Suite("OverlayLayout")
struct OverlayLayoutTests {

    private let estimate = NSSize(width: 260, height: 44)

    /// The regression this type exists for: before SwiftUI's first layout
    /// pass, fittingSize is zero — and treating that as "skip" left the
    /// panel unplaced at (0,0), flush in the bottom-left corner.
    @Test("Zero fitting size resolves to the estimate, never to zero")
    func zeroFittingUsesEstimate() {
        let size = OverlayLayout.resolvedSize(fitting: .zero, applied: .zero, estimate: estimate)
        #expect(size == estimate)
    }

    @Test("A real fitting size wins over everything")
    func realFittingWins() {
        let fitting = NSSize(width: 300, height: 50)
        let applied = NSSize(width: 200, height: 40)
        #expect(
            OverlayLayout.resolvedSize(fitting: fitting, applied: applied, estimate: estimate)
                == fitting
        )
    }

    @Test("A transiently invalid fitting size keeps the last applied size")
    func invalidFittingKeepsApplied() {
        let applied = NSSize(width: 200, height: 40)
        #expect(
            OverlayLayout.resolvedSize(fitting: .zero, applied: applied, estimate: estimate)
                == applied
        )
    }
}
