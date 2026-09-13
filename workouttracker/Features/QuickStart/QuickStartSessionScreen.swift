import SwiftUI
import SwiftData

struct QuickStartSessionScreen: View {
    let sessionID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [TrackedActivitySession]

    @State private var errorMessage: String?
    @State private var clockSource = QuickStartClockSource()

    private let recorder = QuickStartRecorder()

    init(sessionID: UUID) {
        self.sessionID = sessionID
        _sessions = Query(
            filter: #Predicate<TrackedActivitySession> { session in
                session.id == sessionID
            },
            sort: [SortDescriptor(\TrackedActivitySession.updatedAt, order: .reverse)]
        )
    }

    var body: some View {
        Group {
            if let session = sessions.first {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    sessionContent(session, sample: clockSource.sample())
                }
            } else {
                ContentUnavailableView(
                    String(localized: "quickstart.not_found.title", defaultValue: "Timer not found"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(localized: "quickstart.not_found.message", defaultValue: "This timer is no longer available."))
                )
            }
        }
        .navigationBarBackButtonHidden(sessions.first?.isActive == true)
        .alert(
            String(localized: "quickstart.update_error.title", defaultValue: "Could not update timer"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "common.unknown_error", defaultValue: "Unknown error"))
        }
        .accessibilityIdentifier("QuickStart.Session.Screen")
    }

    @ViewBuilder
    private func sessionContent(_ session: TrackedActivitySession, sample: QuickStartClockSample) -> some View {
        switch presentation(for: session, sample: sample) {
        case .success(let value):
            timerContent(session: session, payload: value.payload, presentation: value.presentation)
        case .failure:
            ContentUnavailableView(
                String(localized: "quickstart.invalid.title", defaultValue: "Timer needs attention"),
                systemImage: "exclamationmark.triangle",
                description: Text(String(localized: "quickstart.invalid.message", defaultValue: "The saved timer data could not be read. Your record has not been changed."))
            )
        }
    }

    private func timerContent(
        session: TrackedActivitySession,
        payload: QuickStartTimingPayload,
        presentation: QuickStartSessionPresentation
    ) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "timer")
                    .font(.system(size: 42))
                    .foregroundStyle(.tint)

                Text(quickStartStyleTitle(presentation.style))
                    .font(.title.bold())

                if presentation.style == nil {
                    Text(presentation.styleRaw)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                switch presentation.timingStatus {
                case .elapsed(let seconds):
                    Text(TrackedActivitySummaryBuilder.formatDuration(seconds))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityIdentifier("QuickStart.Session.Elapsed")
                    controls(session: session, payload: payload, presentation: presentation)
                case .recoveryRequired:
                    recoveryControls(session: session, payload: payload)
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .navigationTitle(String(localized: "quickstart.session.title", defaultValue: "Timer"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func controls(
        session: TrackedActivitySession,
        payload: QuickStartTimingPayload,
        presentation: QuickStartSessionPresentation
    ) -> some View {
        switch presentation.phase {
        case .running:
            Text(String(localized: "quickstart.state.running", defaultValue: "Running"))
                .foregroundStyle(.secondary)
            Button(String(localized: "quickstart.pause", defaultValue: "Pause")) {
                apply(.pause, session: session, payload: payload)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("QuickStart.Session.Pause")

            Button(String(localized: "quickstart.finish", defaultValue: "Finish workout"), role: .destructive) {
                apply(.finish, session: session, payload: payload)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("QuickStart.Session.Finish")
        case .paused:
            Text(String(localized: "quickstart.state.paused", defaultValue: "Paused"))
                .foregroundStyle(.secondary)
            Button(String(localized: "quickstart.resume", defaultValue: "Resume")) {
                apply(.resume, session: session, payload: payload)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("QuickStart.Session.Resume")

            Button(String(localized: "quickstart.finish", defaultValue: "Finish workout"), role: .destructive) {
                apply(.finish, session: session, payload: payload)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("QuickStart.Session.Finish")
        case .completed:
            Text(String(localized: "quickstart.state.completed", defaultValue: "Completed"))
                .font(.headline)
            Text(String(localized: "quickstart.completed.help", defaultValue: "Only your active duration was recorded. No reps, weight, distance, calories, or program progress were added."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "common.done", defaultValue: "Done")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("QuickStart.Session.Done")
        case .idle:
            EmptyView()
        }
    }

    private func recoveryControls(
        session: TrackedActivitySession,
        payload: QuickStartTimingPayload
    ) -> some View {
        VStack(spacing: 14) {
            Label(
                String(localized: "quickstart.recovery.title", defaultValue: "Check this timer"),
                systemImage: "clock.badge.exclamationmark"
            )
            .font(.headline)

            Text(String(localized: "quickstart.recovery.message", defaultValue: "The clock changed or this timer was unattended for too long. Choose what to do; uncertain time will not be counted automatically."))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(String(localized: "quickstart.recovery.pause", defaultValue: "Pause at last saved time")) {
                resolve(.pauseAtLastSavedTime, session: session, payload: payload)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("QuickStart.Session.RecoveryPause")

            Button(String(localized: "quickstart.recovery.finish", defaultValue: "Finish at last saved time"), role: .destructive) {
                resolve(.finishAtLastSavedTime, session: session, payload: payload)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("QuickStart.Session.RecoveryFinish")
        }
        .padding(18)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("QuickStart.Session.Recovery")
    }

    private func presentation(
        for session: TrackedActivitySession,
        sample: QuickStartClockSample
    ) -> Result<(payload: QuickStartTimingPayload, presentation: QuickStartSessionPresentation), Error> {
        Result {
            guard let data = session.quickStartTimingBlob else {
                throw QuickStartRecorder.RecordingError.invalidRecord
            }
            let payload = try JSONDecoder().decode(QuickStartTimingPayload.self, from: data)
            return (payload, try QuickStartSessionPresentation(payload: payload, at: sample))
        }
    }

    private func apply(
        _ action: QuickStartTimingState.Action,
        session: TrackedActivitySession,
        payload: QuickStartTimingPayload
    ) {
        do {
            try recorder.apply(
                action,
                to: session,
                id: UUID(),
                expectedRevision: payload.timing.revision,
                at: clockSource.sample(),
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolve(
        _ resolution: QuickStartTimingState.RecoveryResolution,
        session: TrackedActivitySession,
        payload: QuickStartTimingPayload
    ) {
        do {
            try recorder.resolveRecovery(
                resolution,
                for: session,
                id: UUID(),
                expectedRevision: payload.timing.revision,
                at: clockSource.sample(),
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
