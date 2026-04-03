import SwiftUI
import SwiftData

struct TrackedActivitySessionScreen: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)])
    private var trackedSessions: [TrackedActivitySession]

    @State private var errorMessage: String?
    @State private var showDiscardConfirmation = false
    @State private var showFinishSummary = false

    private let recorder = TrackedActivityRecorder()
    private let summaryBuilder = TrackedActivitySummaryBuilder()

    private var session: TrackedActivitySession? {
        trackedSessions.first(where: { $0.id == sessionID })
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(for: session)
                        liveTimerCard(for: session)
                        metricsSection(for: session)
                        notesSection(for: session)
                        actionSection(for: session)
                    }
                    .padding(16)
                }
                .navigationTitle(session.activityKind.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Could not update activity", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "Unknown error")
                }
                .confirmationDialog(
                    "Discard this tracked activity?",
                    isPresented: $showDiscardConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Discard activity", role: .destructive) {
                        discard(session)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the live activity session before it is completed.")
                }
                .navigationDestination(isPresented: $showFinishSummary) {
                    TrackedActivityFinishSummaryView(sessionID: sessionID)
                }
                .onAppear {
                    WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
                    WorkoutRemoteControlRouter.shared.refreshNowPlaying()
                }
                .onDisappear {
                    WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
                }
                .accessibilityIdentifier("TrackedActivitySession.Screen")
            } else {
                ContentUnavailableView(
                    "Tracked activity not found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The selected tracked activity no longer exists.")
                )
            }
        }
    }

    @ViewBuilder
    private func header(for session: TrackedActivitySession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(session.activityKind.displayName, systemImage: session.activityKind.systemImage)
                .font(.title2.bold())

            Text(session.activityKind.helperText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                badge(text: session.lifecycleState.badgeText, color: badgeColor(for: session.lifecycleState))
                badge(text: session.environment.displayName, color: .secondary)
            }
        }
    }

    @ViewBuilder
    private func liveTimerCard(for session: TrackedActivitySession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let totals = recorder.liveTotals(for: session, now: context.date)

            VStack(alignment: .leading, spacing: 10) {
                Text("Live duration")
                    .font(.headline)

                Text(TrackedActivitySummaryBuilder.formatDuration(totals.elapsedDuration))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(timerFooter(for: session))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    @ViewBuilder
    private func metricsSection(for session: TrackedActivitySession) -> some View {
        let metrics = summaryBuilder.metrics(for: session)

        VStack(alignment: .leading, spacing: 12) {
            Text("Current metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(metrics.filter { $0.kind != .state }) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(metric.value)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            if session.activityKind.supportsDistance {
                Text("Distance, steps, and energy can be refined when you finish this activity.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func notesSection(for session: TrackedActivitySession) -> some View {
        if let notes = session.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func actionSection(for session: TrackedActivitySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.lifecycleState == .inProgress {
                Button("Pause") {
                    pause(session)
                }
                .buttonStyle(.bordered)

                Button("Finish") {
                    finish(session)
                }
                .buttonStyle(.borderedProminent)

                Button("Discard", role: .destructive) {
                    showDiscardConfirmation = true
                }
                .buttonStyle(.bordered)
            } else if session.lifecycleState == .paused {
                Button("Resume") {
                    resume(session)
                }
                .buttonStyle(.borderedProminent)

                Button("Finish") {
                    finish(session)
                }
                .buttonStyle(.bordered)

                Button("Discard", role: .destructive) {
                    showDiscardConfirmation = true
                }
                .buttonStyle(.bordered)
            } else if session.lifecycleState == .completed {
                NavigationLink {
                    TrackedActivityFinishSummaryView(sessionID: session.id)
                } label: {
                    Text("Open summary")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if session.lifecycleState == .discarded {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pause(_ session: TrackedActivitySession) {
        do {
            try recorder.pause(session, context: modelContext)
            WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
            WorkoutRemoteControlRouter.shared.refreshNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resume(_ session: TrackedActivitySession) {
        do {
            try recorder.resume(session, context: modelContext)
            WorkoutRemoteControlRouter.shared.focusTrackedActivity(sessionID: session.id)
            WorkoutRemoteControlRouter.shared.refreshNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish(_ session: TrackedActivitySession) {
        do {
            try recorder.complete(session, context: modelContext)
            WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
            WorkoutRemoteControlRouter.shared.refreshNowPlaying()
            showFinishSummary = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func discard(_ session: TrackedActivitySession) {
        do {
            try recorder.discard(session, context: modelContext)
            WorkoutRemoteControlRouter.shared.clearTrackedActivityFocus(sessionID: session.id)
            WorkoutRemoteControlRouter.shared.refreshNowPlaying()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func timerFooter(for session: TrackedActivitySession) -> String {
        switch session.lifecycleState {
        case .inProgress:
            return "The timer is live. Finish when you are done, then add any available metrics to the summary."
        case .paused:
            return "This tracked activity is paused. Resume to continue timing or finish to save what you already recorded."
        case .completed:
            return "This tracked activity is complete. You can review and refine the final summary."
        case .discarded:
            return "This tracked activity was discarded."
        case .planned:
            return "This tracked activity has not started yet."
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func badgeColor(for state: TrackedActivityLifecycleState) -> Color {
        switch state {
        case .planned:
            return .secondary
        case .inProgress:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .blue
        case .discarded:
            return .secondary
        }
    }
}
