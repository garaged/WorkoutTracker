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
                            message: "Some sections are already useful, but more completed workouts will make the trends steadier and fill the missing cards."
                        )
                    )
                }

                if !content.cards.isEmpty {
                    section(title: "Highlights") {
                        LazyVStack(spacing: 12) {
                            ForEach(content.cards) { card in
                                ProgressShellCard(card: card)
                            }
                        }
                    }
                }

                if !content.featuredExercises.isEmpty {
                    section(title: "Featured exercises") {
                        LazyVStack(spacing: 12) {
                            ForEach(content.featuredExercises) { row in
                                ProgressExerciseRow(row: row)
                            }
                        }
                    }
                }

                if !content.unavailableSections.isEmpty {
                    section(title: "Still building") {
                        LazyVStack(spacing: 12) {
                            ForEach(content.unavailableSections) { section in
                                ProgressEmptyStateView(
                                    kind: .sectionUnavailable(
                                        title: section.title,
                                        message: section.message
                                    )
                                )
                            }
                        }
                    }
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

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

private struct ProgressShellCard: View {
    let card: ProgressDashboardViewModel.InsightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline)
                    Text(availabilityText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(availabilityColor)
                }

                Spacer()

                Text(card.value)
                    .font(.title3.weight(.semibold))
            }

            Text(card.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.quaternary)
        )
    }

    private var availabilityText: String {
        switch card.availability {
        case .full:
            return "Ready"
        case .partial:
            return "Low data"
        case .insufficient:
            return "Unavailable"
        }
    }

    private var availabilityColor: Color {
        switch card.availability {
        case .full:
            return .secondary
        case .partial:
            return .orange
        case .insufficient:
            return .red
        }
    }
}

private struct ProgressExerciseRow: View {
    let row: ProgressDashboardViewModel.ExerciseRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.exerciseName)
                    .font(.body.weight(.semibold))
                Text(row.highlight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var statusText: String {
        switch row.availability {
        case .full:
            return "Ready"
        case .partial:
            return "Early"
        case .insufficient:
            return "Low"
        }
    }

    private var statusColor: Color {
        switch row.availability {
        case .full:
            return .secondary
        case .partial:
            return .orange
        case .insufficient:
            return .red
        }
    }
}
