import SwiftUI

/// Timbre for Apple Watch (GDR-0026): the to-do key on the wrist, the word
/// of the day at a glance, Spell it, a word you heard. Runs with no phone
/// in range and no model.
@main
struct TimbreWatchApp: App {

    private let model = WatchModel.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: model)
        }
    }
}
