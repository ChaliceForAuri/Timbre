import SwiftUI
import TimbreKit

/// The practice window: opened from the menu or from Settings › Library.
enum PracticeWindow {
    static let id = "practice"

    @MainActor
    static func open(_ openWindow: OpenWindowAction) {
        NSApp.activate()
        openWindow(id: id)
    }
}
