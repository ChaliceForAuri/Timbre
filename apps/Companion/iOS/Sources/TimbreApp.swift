import SwiftUI

/// Timbre for iPhone: a companion, not a port (GDR-0023). Five tabs, and a
/// URL scheme the widgets and the Lock Screen control open the app on.
@main
struct TimbreApp: App {

    private let model = CompanionModel.shared
    @State private var selection: Tab = .today

    var body: some Scene {
        WindowGroup {
            RootView(model: model, selection: $selection)
                .task { await model.start() }
                .onOpenURL { url in
                    if let tab = Tab(url: url) { selection = tab }
                }
        }
    }
}

enum Tab: String, Hashable {
    case today
    case library
    case practice
    case todo
    case you

    /// `timbre://today`, `timbre://todo`, `timbre://practice`.
    init?(url: URL) {
        guard url.scheme == "timbre", let host = url.host() else { return nil }
        self.init(rawValue: host)
    }
}

struct RootView: View {
    let model: CompanionModel
    @Binding var selection: Tab

    var body: some View {
        TabView(selection: $selection) {
            SwiftUI.Tab("Today", systemImage: "sun.max", value: Tab.today) {
                TodayView(model: model, selection: $selection)
            }
            SwiftUI.Tab("Library", systemImage: "books.vertical", value: Tab.library) {
                LibraryView(model: model)
            }
            SwiftUI.Tab("Spell it", systemImage: "textformat.abc", value: Tab.practice) {
                SpellItView(model: model)
            }
            SwiftUI.Tab("To-do", systemImage: "checklist", value: Tab.todo) {
                TodoKeyView(model: model)
            }
            SwiftUI.Tab("You", systemImage: "person", value: Tab.you) {
                YouView(model: model)
            }
        }
        .tint(Retro.mint)
    }
}
