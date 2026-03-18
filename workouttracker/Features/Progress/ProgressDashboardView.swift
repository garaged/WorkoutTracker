import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ProgressDashboardViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .emptyNoWorkouts:
                emptyDashboardView
            case .failed(let message):
                failureView(message: message)
            case .lowData(let content):
                dashboard(content: content, isLowData: true)
            case .content(let content):
                dashboard(content: content, isLowData: false)
            }
        }
        .navigationTitle("progress.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            isPresented: Binding(
                get: { viewModel.selectedExerciseID != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearExerciseSelection()
                    }
                }
            )
        ) {
            if let exerciseID = viewModel.selectedExerciseID {
                ExerciseProgressDetailView(exerciseID: exerciseID)
            }
        }
        .task {
            viewModel.configureIfNeeded(context: modelContext)
            if case .idle = viewModel.state {
                viewModel.load()
            }
        }
        .refreshable {
            viewModel.configureIfNeeded(context: modelContext)
            viewModel.refresh()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("progress.dashboard.loading")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityIdentifier("Progress.Dashboard.Loading")
    }

    private var emptyDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressEmptyStateView(kind: .noWorkouts)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("Progress.Dashboard.Empty")
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView(
            "progress.dashboard.failure_title",
            systemImage: "exclamationmark.triangle",
            description: Text(verbatim: message)
        )
        .accessibilityIdentifier("Progress.Dashboard.Failure")
    }

    private func dashboard(
        content: ProgressDashboardViewModel.DashboardContent,
        isLowData: Bool
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(content: content)

                if isLowData {
                    ProgressEmptyStateView(
                        kind: .lowData(
                            message: String(localized: "progress.dashboard.low_data_banner")
                        )
                    )
                    .accessibilityIdentifier("Progress.Dashboard.LowDataBanner")
                }

                LazyVStack(spacing: 14) {
                    StrengthProgressCard(model: content.strength) { exerciseID in
                        viewModel.openExerciseDetail(exerciseID: exerciseID)
                    }

                    VolumeTrendCard(
                        model: content.volume,
                        drillDownExerciseID: content.summary.featuredExercises.first?.exerciseID,
                        drillDownExerciseName: content.summary.featuredExercises.first?.exerciseName,
                        onOpenExercise: { exerciseID in
                            viewModel.openExerciseDetail(exerciseID: exerciseID)
                        }
                    )

                    ConsistencyCard(model: content.consistency)
                        .accessibilityIdentifier("Progress.Dashboard.ConsistencyCard")
                    RecoveryInsightCard(model: content.recovery)
                        .accessibilityIdentifier("Progress.Dashboard.RecoveryCard")
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("Progress.Dashboard.Screen")
    }

    private func header(content: ProgressDashboardViewModel.DashboardContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("progress.dashboard.header_title")
                .font(.title2.weight(.semibold))

            Text("progress.dashboard.header_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.localizedWindowLabel(content.windowTitle))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: headerAccessibilityLabel(content: content)))
        .accessibilityIdentifier("Progress.Dashboard.Header")
    }

    private func headerAccessibilityLabel(content: ProgressDashboardViewModel.DashboardContent) -> String {
        [
            String(localized: "progress.dashboard.header_title"),
            String(localized: "progress.dashboard.header_subtitle"),
            viewModel.localizedWindowLabel(content.windowTitle)
        ].joined(separator: ". ")
    }
}
