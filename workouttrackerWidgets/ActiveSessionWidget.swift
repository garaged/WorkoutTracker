import WidgetKit
import SwiftUI

struct ActiveSessionEntry: TimelineEntry {
    let date: Date
    let model: ActiveSessionWidgetViewModel
}

struct ActiveSessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveSessionEntry {
        ActiveSessionEntry(
            date: Date(),
            model: WidgetSnapshotAdapters.activeSessionModel(from: nil)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveSessionEntry) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        completion(ActiveSessionEntry(date: Date(), model: WidgetSnapshotAdapters.activeSessionModel(from: snapshot)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveSessionEntry>) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        let entry = ActiveSessionEntry(date: Date(), model: WidgetSnapshotAdapters.activeSessionModel(from: snapshot))
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct ActiveSessionWidget: Widget {
    static let kind = "ActiveSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ActiveSessionProvider()) { entry in
            ActiveSessionWidgetView(entry: entry)
                .widgetURL(entry.model.url)
        }
        .configurationDisplayName("Active Session")
        .description("Resume your current workout and glance at the next set.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ActiveSessionWidgetView: View {
    let entry: ActiveSessionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.model.title)
                .font(.headline)
                .lineLimit(2)

            Text(entry.model.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 4)

            if let accessoryText = entry.model.accessoryText {
                Text(accessoryText)
                    .font(.caption.weight(.semibold))
            }

            if let footnote = entry.model.footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
