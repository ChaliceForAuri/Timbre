import Foundation

/// Pure sizing decisions for the overlay panel, extracted so the regression
/// that parked the pill at (0,0) stays testable without a window server.
nonisolated enum OverlayLayout {

    /// The size to lay the panel out with right now.
    ///
    /// SwiftUI reports a zero `fittingSize` until its first real layout pass,
    /// which is *after* the panel first needs to be placed on screen. A zero
    /// size must therefore resolve to something usable — the last applied
    /// size if one exists, an estimate if not — because the caller uses it
    /// for placement, and skipping placement leaves an AppKit window at its
    /// creation origin: the bottom-left corner of the screen.
    static func resolvedSize(fitting: NSSize, applied: NSSize, estimate: NSSize) -> NSSize {
        if fitting.width >= 1, fitting.height >= 1 { return fitting }
        if applied.width >= 1, applied.height >= 1 { return applied }
        return estimate
    }
}
