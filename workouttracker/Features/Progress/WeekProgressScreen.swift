import SwiftUI
import SwiftData

struct WeekProgressScreen: View {
    @Environment(\.modelContext) private var modelContext

    private let service = ProgressSummaryService()

    @State private var weeksBack: Int = 12
    @State private var summary: ProgressSummaryService.Summary? = nil
    @State private var loadError: String? = nil

    var body: some View {
        Group {
            if let summary {
                List {
                    Section {
                        HStack {
                            StatChip(title: "Current streak", value: "\(summary.currentStreakDays)d")
                            StatChip(title: "Longest streak", value: "\(summary.longestStreakDays)d")
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        Picker("Window", selection: $weeksBack) {
                            Text("4w").tag(4)
                            Text("12w").tag(12)
                            Text("24w").tag(24)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Weeks") {
                        ForEach(summary.weeks) { w in
                            WeekRow(w: w)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if let loadError {
                ContentUnavailableView(
                    "Couldn’t load progress",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Loading…")
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: weeksBack) { reload() }
        .refreshable {reload()}
    }

    @MainActor
    private func reload() {
        do {
            summary = try service.summarize(weeksBack: weeksBack, context: modelContext)
            loadError = nil
        } catch {
            summary = nil
            loadError = String(describing: error)
        }
    }
}

private struct WeekRow: View {
    let w: ProgressSummaryService.WeekStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(weekTitle)
                    .font(.headline)
                Spacer()
                Text("\(w.workoutsCompleted) workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                StatChip(title: "Sets", value: "\(w.totalSetsCompleted)")
                StatChip(title: "Volume", value: formatVolume(w.totalVolume))
                StatChip(title: "Time", value: formatDuration(w.timeTrainedSeconds))
            }
        }
        .padding(.vertical, 6)
    }

    private var weekTitle: String {
        let start = w.weekStart.formatted(.dateTime.month(.abbreviated).day())
        // weekEndExclusive is exclusive; show the “inclusive” end in UI
        let endInclusive = Calendar.current.date(byAdding: .day, value: -1, to: w.weekEndExclusive) ?? w.weekEndExclusive
        let end = endInclusive.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let r = m % 60
        return "\(h)h \(r)m"
    }

    private func formatVolume(_ v: Double) -> String {
        if v.rounded() == v { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }
}
