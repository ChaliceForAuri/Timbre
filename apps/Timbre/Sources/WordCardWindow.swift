import SwiftUI
import TimbreKit

/// The card's window: opened from the menu, from Settings, or by the
/// morning notification. A normal window, because the user asked for it.
enum WordCardWindow {
    static let id = "word-of-the-day"

    @MainActor
    static func open(_ openWindow: OpenWindowAction) {
        NSApp.activate()
        openWindow(id: id)
    }
}
