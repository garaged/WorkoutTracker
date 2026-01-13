import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: Exercise

    @State private var points: [HistoryPoint] = []
    @State private var metric: HistoryMetric = .volume
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if !statsChips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(statsChips, id: \.title) { c in
                                StatChip(title: c.title, value: c.value, systemImage: c.systemImage)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                chartCard

                detailsCard

                recentSessionsCard
            }
            .padding(16)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ExerciseEditorSheet(exercise: exercise)
        }
        .task(id: exercise.id) {
            await loadHistory()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName(exercise.modality))
                    .foregroundStyle(.tint)
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                Spacer()
            }

            if !exercise.equipmentTags.isEmpty {
                Text(exercise.equipmentTags.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.headline)

                Spacer()

                Picker("Metric", selection: $metric) {
                    Text("Volume").tag(HistoryMetric.volume)
                    Text("Best Weight").tag(HistoryMetric.bestWeight)
                    Text("Sets Done").tag(HistoryMetric.setsDone)
                }
                .pickerStyle(.menu)
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log a session with this exercise to populate trends.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                Chart(points) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value(metric.label, metric.value(p))
                    )
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value(metric.label, metric.value(p))
                    )
                }
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)

            if let txt = exercise.instructions, !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(txt)
                    .font(.body)
            } else {
                Text("No instructions yet.")
                    .foregroundStyle(.secondary)
            }

            if let notes = exercise.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                Text("Notes")
                    .font(.headline)
                Text(notes)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent sessions")
                .font(.headline)

            if points.isEmpty {
                Text("Nothing logged yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(points.suffix(8).reversed()) { p in
                        HStack {
                            Text(p.date.formatted(.dateTime.month(.abbreviated).day()))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(p.summaryText)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data

    @MainActor
    private func loadHistory() async {
        do {
            let exId = exercise.id
            let desc = FetchDescriptor<WorkoutSessionExercise>(
                predicate: #Predicate { se in
                    se.exerciseId == exId
                }
            )
            let rows = try modelContext.fetch(desc)

            // Group by session
            let grouped = Dictionary(grouping: rows.compactMap { se -> (WorkoutSession, WorkoutSessionExercise)? in
                guard let s = se.session else { return nil }
                return (s, se)
            }, by: { $0.0.id })

            var out: [HistoryPoint] = []
            out.reserveCapacity(grouped.count)

            for (_, group) in grouped {
                guard let session = group.first?.0 else { continue }
                let allSets = group.flatMap { $0.1.setLogs }

                let completedSets = allSets.filter { $0.completed }
                let setsDone = completedSets.count

                let bestWeight = completedSets.compactMap { $0.weight }.max()
                    ?? allSets.compactMap { $0.weight }.max()
                    ?? 0

                let volume = completedSets.reduce(0.0) { acc, s in
                    let reps = Double(s.reps ?? 0)
                    let w = s.weight ?? 0
                    return acc + (reps * w)
                }

                out.append(
                    HistoryPoint(
                        id: session.id,
                        date: session.startedAt,
                        volume: volume,
                        bestWeight: bestWeight,
                        setsDone: setsDone
                    )
                )
            }

            out.sort { $0.date < $1.date }
            points = out
        } catch {
            points = []
        }
    }

    private var statsChips: [(title: String, value: String, systemImage: String)] {
        guard !points.isEmpty else { return [] }

        let sessions = points.count
        let last = points.last?.date
        let best = points.map(\.bestWeight).max() ?? 0
        let totalVol = points.map(\.volume).reduce(0, +)

        var chips: [(String, String, String)] = []
        chips.append(("Sessions", "\(sessions)", "calendar"))
        if let last {
            chips.append(("Last", last.formatted(.dateTime.month(.abbreviated).day()), "clock"))
        }
        chips.append(("Best Wt", best == 0 ? "—" : fmt(best), "trophy"))
        chips.append(("Total Vol", totalVol == 0 ? "—" : fmt(totalVol), "sum"))
        return chips
    }

    private func fmt(_ x: Double) -> String {
        let nf = NumberFormatter()
        nf.maximumFractionDigits = 1
        nf.minimumFractionDigits = 0
        return nf.string(from: NSNumber(value: x)) ?? "\(x)"
    }

    private func iconName(_ m: ExerciseModality) -> String {
        switch m {
        case .strength: return "figure.strengthtraining.traditional"
        case .timed: return "timer"
        case .cardio: return "heart"
        case .mobility: return "figure.cooldown"
        }
    }
}

private enum HistoryMetric: Hashable {
    case volume
    case bestWeight
    case setsDone

    var label: String {
        switch self {
        case .volume: return "Volume"
        case .bestWeight: return "Best Weight"
        case .setsDone: return "Sets Done"
        }
    }

    func value(_ p: HistoryPoint) -> Double {
        switch self {
        case .volume: return p.volume
        case .bestWeight: return p.bestWeight
        case .setsDone: return Double(p.setsDone)
        }
    }
}

private struct HistoryPoint: Identifiable {
    let id: UUID
    let date: Date
    let volume: Double
    let bestWeight: Double
    let setsDone: Int

    var summaryText: String {
        let v = volume > 0 ? "Vol \(Int(volume))" : "Vol —"
        let bw = bestWeight > 0 ? "Best \(bestWeight, default: "%.1f")" : "Best —"
        return "\(v) • \(bw) • \(setsDone) sets"
    }
}
