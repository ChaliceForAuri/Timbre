import SwiftUI
import TimbreCore
import WidgetKit

/// The complication and the Smart Stack card (GDR-0026): today's word on
/// the face. Reads the snapshot the Watch app writes; never opens the
/// Library.
@main
struct TimbreWatchWidgets: WidgetBundle {
    var body: some Widget {
        WordComplication()
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
                dayKey: "", term: "ephemeral", summary: "ephemeral — short-lived", why: "", metToday: false)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

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

struct WordComplication: Widget {
    let kind = "dev.hugopretorius.Timbre.watch.word-of-the-day"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordProvider()) { entry in
            WordComplicationView(entry: entry)
        }
        .configurationDisplayName("Word of the day")
        .description("The word in your Library that has faded furthest.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct WordComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WordEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("Word of the day").font(.caption2).foregroundStyle(.secondary)
                    Text(entry.snapshot?.term ?? "Nothing due").font(.headline).lineLimit(1)
                    if let snapshot = entry.snapshot {
                        Text(snapshot.metToday ? "Met today" : snapshot.why).font(.caption2).lineLimit(1)
                    }
                }
            case .accessoryInline:
                Text(entry.snapshot.map { "Word: \($0.term)" } ?? "Timbre")
            default:
                VStack(spacing: 0) {
                    Image(systemName: "text.book.closed").font(.caption)
                    Text(entry.snapshot?.term.prefix(5) ?? "—").font(.caption2).lineLimit(1)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
