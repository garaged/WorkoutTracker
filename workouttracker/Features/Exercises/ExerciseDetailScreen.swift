import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    @Environment(\.modelContext) private var modelContext

    let exercise: Exercise

    /// Shortcut hook. Default keeps existing call sites unchanged.
    let startWorkoutAction: ((Exercise) -> Void)?

    @State private var history: [WorkoutSetLog] = []
    @State private var records: PersonalRecordsService.PersonalRecords?
    @State private var trendPoints: [PersonalRecordsService.TrendPoint] = []
    @State private var loadError: String?

    private let prService = PersonalRecordsService()

    init(exercise: Exercise, startWorkoutAction: ((Exercise) -> Void)? = nil) {
        self.exercise = exercise
        self.startWorkoutAction = startWorkoutAction
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let instructions = exercise.instructions,
                   !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionTitle("Instructions")
                    Text(instructions)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let notes = exercise.notes,
                   !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionTitle("Notes")
                    Text(notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                }

                // ✅ “Sticky” CTA comes early
                if let startWorkoutAction {
                    Button {
                        startWorkoutAction(exercise)
                    } label: {
                        Label("Start workout with this exercise", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // ✅ PRs + trend are the “sticky” part (actionable at a glance)
                if let records {
                    ExercisePRSummaryView(records: records)
                } else if loadError == nil {
                    ProgressView().frame(maxWidth: .infinity)
                }

                ExerciseTrendChartView(points: trendPoints)

                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Raw history stays below
                historySection
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: exercise.id) {
            await loadAll()
        }
        .refreshable {
            await loadAll()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.title2.weight(.bold))
                Spacer()
                Text(exercise.modality.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            mediaPreview
        }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        switch exercise.mediaKind {
        case .none:
            RoundedRectangle(cornerRadius: 16)
                .fill(.secondary.opacity(0.08))
                .frame(height: 180)
                .overlay {
                    ContentUnavailableView(
                        "No media",
                        systemImage: "photo",
                        description: Text("Add an asset name later (Phase D+).")
                    )
                }

        case .bundledAsset:
            if let name = exercise.mediaAssetName, !name.isEmpty {
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.08))
                    .frame(height: 180)
            }

        case .remoteURL:
            RoundedRectangle(cornerRadius: 16)
                .fill(.secondary.opacity(0.08))
                .frame(height: 180)
                .overlay {
                    ContentUnavailableView(
                        "Remote media",
                        systemImage: "link",
                        description: Text("We’ll support loading remote video/GIF later.")
                    )
                }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    WorkoutHistoryScreen(filter: .exercise(exerciseId: exercise.id, exerciseName: exercise.name))
                } label: {
                    Text("See all")
                }
                .font(.subheadline)
            }

            if history.isEmpty {
                ContentUnavailableView(
                    "No logged sets yet",
                    systemImage: "clock",
                    description: Text("Complete sets in a workout session to see history here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let points = chartPoints(from: history)

                VStack(alignment: .leading, spacing: 10) {
                    statsRow(history)

                    Chart(points) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Value", p.value)
                        )
                    }
                    .frame(height: 180)

                    Text(pointsCaption(points))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsRow(_ sets: [WorkoutSetLog]) -> some View {
        let completedCount = sets.count
        let last = sets.compactMap(\.completedAt).max()
        return HStack(spacing: 10) {
            statPill(title: "Sets", value: "\(completedCount)")
            if let last {
                statPill(title: "Last", value: last.formatted(.dateTime.month(.abbreviated).day()))
            }
            Spacer()
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @MainActor
    private func loadAll() async {
        await loadHistory()
        await reloadPRsAndTrends()
    }

    @MainActor
    private func reloadPRsAndTrends() async {
        do {
            loadError = nil
            records = try prService.records(for: exercise.id, context: modelContext)
            trendPoints = try prService.trend(for: exercise.id, limit: 24, context: modelContext)
        } catch {
            loadError = "Progress failed to load: \(error)"
            records = nil
            trendPoints = []
        }
    }

    // MARK: - History loading

    @MainActor
    private func loadHistory() async {
        // ✅ capture plain value outside the predicate macro
        let exId: UUID? = exercise.id

        do {
            let desc = FetchDescriptor<WorkoutSetLog>(
                predicate: #Predicate<WorkoutSetLog> { s in
                    s.completed == true &&
                    s.sessionExercise?.exerciseId == exId
                },
                sortBy: [SortDescriptor(\WorkoutSetLog.completedAt, order: .forward)]
            )
            history = try modelContext.fetch(desc).filter { $0.completedAt != nil }
        } catch {
            history = []
        }
    }

    // MARK: - Chart mapping

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let unit: String?
    }

    private func chartPoints(from sets: [WorkoutSetLog]) -> [Point] {
        return sets.compactMap { s in
            guard let d = s.completedAt else { return nil }
            switch exercise.modality {
            case .strength:
                return Point(date: d, value: s.weight ?? 0, unit: s.weightUnit.rawValue)
            case .timed, .cardio, .mobility:
                return Point(date: d, value: Double(s.reps ?? 0), unit: nil)
            }
        }
    }

    private func pointsCaption(_ points: [Point]) -> String {
        switch exercise.modality {
        case .strength:
            let unit = points.last?.unit ?? ""
            return "Weight over time \(unit.isEmpty ? "" : "(\(unit))")"
        case .timed:
            return "Seconds over time"
        case .cardio:
            return "Effort over time"
        case .mobility:
            return "Reps/seconds over time"
        }
    }
}
