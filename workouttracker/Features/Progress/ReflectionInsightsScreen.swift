import SwiftUI
import SwiftData

/// Local “Reflection rate” dashboard.
/// Lives under Progress because it's a retention-style metric that users can revisit.
struct ReflectionInsightsScreen: View {
    @Environment(\.modelContext) private var modelContext

    private let service = ReflectionInsightsService()

    @State private var weeksBack: Int = 12
    @State private var summary: ReflectionInsightsService.Summary? = nil
    @State private var loadError: String? = nil

    var body: some View {
        Group {
            if let summary {
                List {
                    Section {
                        Picker(AppFormatting.localized("Window"), selection: $weeksBack) {
                            Text(AppFormatting.localized("4w")).tag(4)
                            Text(AppFormatting.localized("12w")).tag(12)
                            Text(AppFormatting.localized("24w")).tag(24)
                        }
                        .pickerStyle(.segmented)
                    }

                    if summary.completedSessions == 0 {
                        Section {
                            EmptyStateView(
                                title: String(localized: "No completed sessions yet"),
                                message: String(localized: "Finish a workout to start building reflection stats."),
                                systemImage: "face.smiling"
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                    } else {
                        Section(AppFormatting.localized("Reflection rate")) {
                            HStack {
                                StatChip(title: String(localized: "Rate"), value: rateText(summary.reflectionRate))
                                StatChip(title: String(localized: "Reflected"), value: "\(summary.sessionsWithReflection)/\(summary.completedSessions)")
                                StatChip(title: String(localized: "Mood used"), value: "\(summary.sessionsWithMood)")
                            }
                            .padding(.vertical, 4)

                            HStack {
                                StatChip(title: String(localized: "Mood only"), value: "\(summary.moodOnly)")
                                StatChip(title: String(localized: "Note only"), value: "\(summary.noteOnly)")
                                StatChip(title: String(localized: "Both"), value: "\(summary.bothMoodAndNote)")
                            }
                            .padding(.vertical, 4)
                        }

                        Section(AppFormatting.localized("Mood breakdown")) {
                            if summary.moodStats.isEmpty {
                                Text(AppFormatting.localized("No moods recorded in this window yet."))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(summary.moodStats) { m in
                                    HStack {
                                        Text(moodLabel(m.mood))
                                        Spacer()
                                        Text("\(m.count)")
                                            .foregroundStyle(.secondary)
                                        Text(percentText(m.percentOfMoods))
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        Section {
                            Text(
                                String(
                                    format: String(localized: "Window: %@"),
                                    locale: .autoupdatingCurrent,
                                    windowText(summary)
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if let loadError {
                ContentUnavailableView(AppFormatting.localized("Couldn’t load reflection stats"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView(AppFormatting.localized("Loading…"))
            }
        }
        .navigationTitle(AppFormatting.localized("Reflections"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: weeksBack) { reload() }
        .refreshable { reload() }
    }

    @MainActor
    private func reload() {
        do {
            summary = try service.summarize(weeksBack: weeksBack, context: modelContext)
            loadError = nil
        } catch {
            AppLogger.shared.error("ReflectionInsights reload failed: \(String(describing: error))", category: .persistence)
            summary = nil
            loadError = String(describing: error)
        }
    }

    private func rateText(_ r: Double?) -> String {
        guard let r else { return "—" }
        return percentText(r)
    }

    private func percentText(_ v: Double) -> String {
        let pct = (v * 100).formatted(.number.precision(.fractionLength(0...0)))
        return String(format: String(localized: "%@%%"), locale: .autoupdatingCurrent, pct)
    }

    private func moodLabel(_ mood: SessionReflectionMood) -> String {
        // Prefer your enum's display helpers if you have them.
        // (Your v1 implementation includes `emoji` + `title`.)
        switch mood {
        case .great: return String(localized: "😄 Great")
        case .good: return String(localized: "🙂 Good")
        case .neutral: return String(localized: "😐 Neutral")
        case .tough: return String(localized: "😮‍💨 Tough")
        case .bad: return String(localized: "😞 Bad")
        }
    }

    private func windowText(_ s: ReflectionInsightsService.Summary) -> String {
        let endInclusive = Calendar.current.date(byAdding: .day, value: -1, to: s.windowEndExclusive) ?? s.windowEndExclusive
        return AppFormatting.dateRange(start: s.windowStart, end: endInclusive)
    }
}
