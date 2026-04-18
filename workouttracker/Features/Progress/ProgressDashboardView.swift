import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedActivitySessions: [TrackedActivitySession]
    @StateObject private var viewModel = ProgressDashboardViewModel()
    @State private var trackedActivityCardModel: TrackedActivitySummaryCardModel?

    private let trackedActivityCardBuilder = TrackedActivityProgressCardBuilder()

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
        .navigationTitle(String(localized: "progress.title"))
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
            updateTrackedActivityCardModel()
        }
        .refreshable {
            viewModel.configureIfNeeded(context: modelContext)
            viewModel.refresh()
        }
        .onChange(of: trackedActivityCardBuilder.signature(for: trackedActivitySessions)) { _, _ in
            updateTrackedActivityCardModel()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "progress.dashboard.loading"))
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
            String(localized: "progress.dashboard.failure_title"),
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
                    if let trackedActivityCardModel {
                        sectionHeader(
                            title: String(localized: "progress.section.tracked_activities", defaultValue: "Tracked activities"),
                            subtitle: String(localized: "progress.section.tracked_activities.subtitle", defaultValue: "Walking, running, hiking, and yoga summaries stay separate from your strength trends."),
                            systemImage: "figure.walk.motion"
                        )

                        TrackedActivitySummaryCard(model: trackedActivityCardModel)
                    }

                    sectionHeader(
                        title: String(localized: "progress.section.strength", defaultValue: "Strength training"),
                        subtitle: String(localized: "progress.section.strength.subtitle", defaultValue: "Volume, consistency, recovery, and featured lifts are shown below."),
                        systemImage: "figure.strengthtraining.traditional"
                    )

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
                    RecoveryInsightCard(model: content.recovery)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("Progress.Dashboard.Screen")
    }


    private func sectionHeader(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private func header(content: ProgressDashboardViewModel.DashboardContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "progress.dashboard.header_title"))
                .font(.title2.weight(.semibold))

            Text(String(localized: "progress.dashboard.header_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(viewModel.localizedWindowLabel(content.windowTitle))
                .font(dynamicTypeSize.isAccessibilitySize ? .body : .caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private func updateTrackedActivityCardModel() {
        trackedActivityCardModel = trackedActivityCardBuilder.build(from: trackedActivitySessions)
    }
}
