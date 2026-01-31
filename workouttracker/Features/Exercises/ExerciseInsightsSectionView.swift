import SwiftUI
import SwiftData

struct ExerciseInsightsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var goalPrefill: GoalPrefillStore

    let exerciseId: UUID
    let exerciseName: String

    /// Optional: if provided, “Start workout and apply” will be shown.
    let startWorkoutAction: (() -> Void)?

    @State private var records: PersonalRecordsService.PersonalRecords?
    @State private var trendPoints: [PersonalRecordsService.TrendPoint] = []
    @State private var nextTarget: PersonalRecordsService.NextTarget?
    @State private var loadError: String?
    @State private var showNextTargetActions = false

    private let prService = PersonalRecordsService()

    init(
        exerciseId: UUID,
        exerciseName: String,
        startWorkoutAction: (() -> Void)? = nil
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.startWorkoutAction = startWorkoutAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let records {
                ExercisePRSummaryView(
                    records: records,
                    nextTargetText: nextTarget?.text,
                    onTapNextTarget: (nextTarget == nil) ? nil : { showNextTargetActions = true }
                )
            } else if loadError == nil {
                ProgressView().frame(maxWidth: .infinity)
            }

            ExerciseTrendChartView(points: trendPoints)

            NavigationLink {
                WorkoutHistoryScreen(filter: .exercise(exerciseId: exerciseId, exerciseName: exerciseName))
            } label: {
                Label("View full history", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
            }

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: exerciseId) { await reload() }
        .confirmationDialog("Next target", isPresented: $showNextTargetActions, titleVisibility: .visible) {
            if startWorkoutAction != nil {
                Button("Start workout and apply target") {
                    applyNextTargetPrefill()
                    startWorkoutAction?()
                }
            }
            Button("Apply target for next workout") {
                applyNextTargetPrefill()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let text = nextTarget?.text { Text(text) }
        }
    }

    @MainActor
    private func reload() async {
        do {
            loadError = nil
            let rec = try prService.records(for: exerciseId, context: modelContext)
            records = rec
            trendPoints = try prService.trend(for: exerciseId, limit: 24, context: modelContext)
            nextTarget = try prService.nextTarget(for: exerciseId, records: rec, context: modelContext)
        } catch {
            loadError = "Progress failed to load: \(error)"
            records = nil
            trendPoints = []
            nextTarget = nil
        }
    }

    @MainActor
    private func applyNextTargetPrefill() {
        guard let t = nextTarget else { return }
        goalPrefill.set(GoalPrefillStore.Prefill(
            exerciseId: exerciseId,
            weight: t.targetWeight,
            reps: t.targetReps
        ))
    }
}
