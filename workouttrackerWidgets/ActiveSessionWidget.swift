import WidgetKit
import SwiftUI

struct ActiveSessionEntry: TimelineEntry {
    let date: Date
    let model: ActiveSessionWidgetViewModel
    let relevance: TimelineEntryRelevance?
}

struct ActiveSessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActiveSessionEntry {
        ActiveSessionEntry(
            date: Date(),
            model: WidgetSnapshotAdapters.activeSessionModel(from: nil),
            relevance: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ActiveSessionEntry) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        let model = WidgetSnapshotAdapters.activeSessionModel(from: snapshot)
        completion(ActiveSessionEntry(date: Date(), model: model, relevance: relevance(for: model)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActiveSessionEntry>) -> Void) {
        let snapshot = WidgetSharedSnapshotReader.load()
        let model = WidgetSnapshotAdapters.activeSessionModel(from: snapshot)
        let entry = ActiveSessionEntry(date: Date(), model: model, relevance: relevance(for: model))
        let refreshInterval: TimeInterval = model.hasSession ? 60 : 900
        let refreshDate = Date().addingTimeInterval(refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func relevance(for model: ActiveSessionWidgetViewModel) -> TimelineEntryRelevance? {
        guard model.hasSession else { return nil }
        return TimelineEntryRelevance(score: 100, duration: 60 * 60)
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
        .description("Resume your current workout or tracked activity.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(watchOS)
        return [.accessoryInline, .accessoryCircular, .accessoryRectangular]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }
}

private struct ActiveSessionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ActiveSessionEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            accessoryInlineView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            systemWidgetView
        }
    }

    private var systemWidgetView: some View {
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

    private var accessoryInlineView: some View {
        Group {
            if entry.model.hasSession {
                if let accessoryText = entry.model.accessoryText {
                    Text("WT \(accessoryText)")
                } else {
                    Text("WT active")
                }
            } else {
                Text("WT")
            }
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: entry.model.hasSession ? "figure.strengthtraining.traditional" : "dumbbell")
                    .font(.caption2)
                if let accessoryText = compactCircularText {
                    Text(accessoryText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.model.title)
                .font(.headline)
                .lineLimit(1)

            Text(entry.model.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let footnote = entry.model.footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var compactCircularText: String? {
        if let accessoryText = entry.model.accessoryText, !accessoryText.isEmpty {
            return accessoryText.replacingOccurrences(of: "Set ", with: "")
        }

        if let footnote = entry.model.footnote, !footnote.isEmpty {
            return footnote.prefix(4).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return entry.model.hasSession ? "Go" : nil
    }
}
