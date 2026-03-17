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
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
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
            Text("Loading progress…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressEmptyStateView(kind: .noWorkouts)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func failureView(message: String) -> some View {
        ContentUnavailableView(
            "Couldn’t load Progress",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
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
                            message: "Some cards are already useful, while others still need more completed workouts or timing data to become trustworthy."
                        )
                    )
                }

                LazyVStack(spacing: 14) {
                    StrengthProgressCard(model: content.strength) { exerciseID in
                        viewModel.openExerciseDetail(exerciseID: exerciseID)
                    }

                    VolumeTrendCard(model: content.volume)
                    ConsistencyCard(model: content.consistency)
                    RecoveryInsightCard(model: content.recovery)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func header(content: ProgressDashboardViewModel.DashboardContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training trends")
                .font(.title2.weight(.semibold))

            Text("A simple dashboard for strength, volume, consistency, and session efficiency.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Window: \(content.windowTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
