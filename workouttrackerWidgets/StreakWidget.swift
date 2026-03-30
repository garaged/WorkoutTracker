import WidgetKit
import SwiftUI

struct StreakEntry: TimelineEntry {
    let date: Date
    let model: StreakWidgetViewModel
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), model: WidgetSnapshotAdapters.streakModel(from: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        completion(StreakEntry(date: Date(), model: WidgetSnapshotAdapters.streakModel(from: snapshot)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        let entry = StreakEntry(date: Date(), model: WidgetSnapshotAdapters.streakModel(from: snapshot))
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct StreakWidget: Widget {
    static let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(entry.model.url)
        }
        .configurationDisplayName("Consistency")
        .description("Keep an honest pulse on your current streak and this week’s momentum.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.model.title)
                .font(.headline)

            Text(entry.model.currentStreakText)
                .font(.title3.weight(.semibold))
                .lineLimit(2)

            Spacer(minLength: 4)

            Text(entry.model.longestStreakText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(entry.model.workoutsThisWeekText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
