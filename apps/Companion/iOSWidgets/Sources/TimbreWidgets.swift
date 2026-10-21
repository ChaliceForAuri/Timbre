import AppIntents
import SwiftUI
import TimbreCore
import WidgetKit

/// The iPhone's widgets (GDR-0027): today's word on the Home and Lock
/// Screens, and a Control that opens the to-do key. They read the snapshot
/// the app writes to the shared container; they never open the Library.
@main
struct TimbreWidgets: WidgetBundle {
    var body: some Widget {
        WordOfTheDayWidget()
        TodoKeyControl()
    }
}

nonisolated struct WordEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot?
}

nonisolated struct WordProvider: TimelineProvider {

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(
            date: .now,
            snapshot: TodaySnapshot(
                dayKey: "", term: "ephemeral", summary: "ephemeral — lasting a very short time", why: "",
                metToday: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    /// One entry, refreshed after midnight; the app reloads the timeline
    /// itself whenever the Library changes.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        completion(Timeline(entries: [current(now)], policy: .after(midnight)))
    }

    func current(_ now: Date = .now) -> WordEntry {
        let snapshot = TodaySnapshot.read(from: SharedContainer.snapshotURL)
        return WordEntry(date: now, snapshot: snapshot.flatMap { $0.isFor(now) ? $0 : nil })
    }
}

struct WordOfTheDayWidget: Widget {
    let kind = "dev.hugopretorius.Timbre.word-of-the-day"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordWidgetView(entry: entry)
        }
        .configurationDisplayName("Word of the day")
        .description("The word in your Library that has faded furthest.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular,
        ])
    }
}

struct WordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.snapshot.map { "Word: \($0.term)" } ?? "Timbre: nothing due")
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "text.book.closed").font(.caption)
                    Text(entry.snapshot?.term.prefix(6) ?? "—").font(.caption2).lineLimit(1)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("Word of the day").font(.caption2).foregroundStyle(.secondary)
                    Text(entry.snapshot?.term ?? "Nothing due").font(.headline).lineLimit(1)
                    if let snapshot = entry.snapshot {
                        Text(snapshot.metToday ? "Met today" : snapshot.why).font(.caption2).lineLimit(1)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("Word of the day")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    if let snapshot = entry.snapshot {
                        Text(snapshot.term)
                            .font(.system(.title2, design: .serif, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        Text(
                            snapshot.summary.hasPrefix(snapshot.term + " — ")
                                ? String(snapshot.summary.dropFirst(snapshot.term.count + 3)) : snapshot.why
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(family == .systemMedium ? 3 : 2)
                        if snapshot.metToday {
                            Label("Met today", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Color(red: 0.28, green: 0.81, blue: 0.64))
                        }
                    } else {
                        Text("Nothing due").font(.title3.weight(.semibold))
                        Spacer(minLength: 0)
                        Text("Add a word and it will come round.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(URL(string: "timbre://today"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Control Center and the Lock Screen: one press opens the to-do key, already
/// listening for the hold.
struct TodoKeyControl: ControlWidget {
    let kind = "dev.hugopretorius.Timbre.todo-key"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "timbre://todo")!)) {
                Label("Say a to-do", systemImage: "checklist")
            }
        }
        .displayName("Say a to-do")
        .description("Opens Timbre on the to-do key.")
    }
}
