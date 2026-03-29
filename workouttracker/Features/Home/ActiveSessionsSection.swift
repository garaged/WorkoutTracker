import SwiftUI
import SwiftData

struct ActiveSessionsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query
    private var activities: [Activity]

    @State private var recoveryPromptSession: WorkoutSession? = nil

    var onResumeRoute: (AppRoute) -> Void = { _ in }

    private let calendar = Calendar.current
    private let sessionResumePlanner = SessionResumePlanner()
    private let attentionEvaluator = SessionAttentionEvaluator()

    private var activityByID: [UUID: Activity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private var activeSessions: [WorkoutSession] {
        sessionResumePlanner.sortedActiveSessions(
            sessions,
            activitiesByID: activityByID
        )
    }

    var body: some View {
        if !activeSessions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(activeSessions) { session in
                    let attention = attentionState(for: session)
                    ActiveSessionCard(
                        session: session,
                        isPastDay: isPastDay(session),
                        attentionState: attention,
                        subtitle: subtitle(for: session),
                        resumeAccessibilityID: isPastDay(session)
                            ? "Home.ActiveSessions.Resume.PreviousDay"
                            : "Home.ActiveSessions.Resume.Today",
                        finishAccessibilityID: isPastDay(session)
                            ? "Home.ActiveSessions.Finish.PreviousDay"
                            : nil,
                        cardAccessibilityID: isPastDay(session)
                            ? "Home.ActiveSessions.Card.PreviousDay"
                            : "Home.ActiveSessions.Card.Today",
                        resumeAction: { handleResumeTap(for: session) },
                        finishAction: { finish(session) }
                    )
                }
            }
            .accessibilityIdentifier("Home.ActiveSessions.Section")
            .sheet(item: $recoveryPromptSession) { session in
                SessionRecoveryPrompt(
                    title: String(localized: "session.recovery.previous_day.title"),
                    message: recoveryPromptMessage(for: session),
                    onResume: {
                        do {
                            try WorkoutSessionStarter.resumeForActiveLogging(session, context: modelContext)
                            recoveryPromptSession = nil
                            onResumeRoute(sessionResumePlanner.resumeRoute(for: session) ?? sessionResumePlanner.openRoute(for: session))
                        } catch {
                            assertionFailure("Failed to resume stale session from Home: \(error)")
                        }
                    },
                    onFinishNow: {
                        do {
                            try WorkoutSessionStarter.finishFromRecovery(session, context: modelContext)
                            recoveryPromptSession = nil
                        } catch {
                            assertionFailure("Failed to finish stale session from Home: \(error)")
                        }
                    },
                    onDiscard: {
                        do {
                            try WorkoutSessionStarter.discardUnfinishedSession(session, context: modelContext)
                            recoveryPromptSession = nil
                        } catch {
                            assertionFailure("Failed to discard stale session from Home: \(error)")
                        }
                    },
                    onKeepForLater: {
                        do {
                            try WorkoutSessionStarter.keepForLater(session, context: modelContext)
                            recoveryPromptSession = nil
                        } catch {
                            assertionFailure("Failed to keep stale session for later from Home: \(error)")
                        }
                    }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if AdaptiveLayoutMetrics.shouldStackActiveSessionCardHeader(dynamicTypeSize: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(AppFormatting.localized("Active Sessions"), systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)

                    Text("\(activeSessions.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Label(AppFormatting.localized("Active Sessions"), systemImage: "figure.strengthtraining.traditional")
                        .font(.headline)

                    Spacer()

                    Text("\(activeSessions.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text(String(localized: "home.active_sessions.help"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func linkedActivity(for session: WorkoutSession) -> Activity? {
        guard let id = session.linkedActivityId else { return nil }
        return activityByID[id]
    }

    private func owningDayDate(for session: WorkoutSession) -> Date {
        linkedActivity(for: session)?.startAt ?? session.startedAt
    }

    private func attentionState(for session: WorkoutSession) -> SessionAttentionState {
        attentionEvaluator.evaluate(session: session, owningDay: owningDayDate(for: session)).state
    }

    private func isPastDay(_ session: WorkoutSession) -> Bool {
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.startOfDay(for: owningDayDate(for: session)) < todayStart
    }

    private func subtitle(for session: WorkoutSession) -> String {
        let startedText: String
        if calendar.isDateInToday(session.startedAt) {
            startedText = String(
                format: String(localized: "Started today at %@"),
                locale: .autoupdatingCurrent,
                session.startedAt.formatted(date: .omitted, time: .shortened)
            )
        } else {
            startedText = String(
                format: String(localized: "Started %@"),
                locale: .autoupdatingCurrent,
                session.startedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }

        let plannedPrefix: String? = {
            guard let activity = linkedActivity(for: session) else { return nil }
            guard !calendar.isDate(activity.startAt, inSameDayAs: session.startedAt) else { return nil }

            if calendar.isDateInToday(activity.startAt) {
                return String(localized: "Planned for today")
            } else if calendar.isDateInYesterday(activity.startAt) {
                return String(localized: "Planned for yesterday")
            } else {
                return String(
                    format: String(localized: "Planned for %@"),
                    locale: .autoupdatingCurrent,
                    activity.startAt.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }()

        let base = plannedPrefix.map { "\($0) · \(startedText)" } ?? startedText

        if session.isPaused {
            return String(
                format: String(localized: "Paused · %@"),
                locale: .autoupdatingCurrent,
                base
            )
        }

        return base
    }

    private func recoveryPromptMessage(for session: WorkoutSession) -> String {
        let owningDay = owningDayDate(for: session)
        let dayText = owningDay.formatted(date: .abbreviated, time: .omitted)
        return String(
            format: String(localized: "session.recovery.previous_day.message"),
            locale: .autoupdatingCurrent,
            dayText
        )
    }

    private func handleResumeTap(for session: WorkoutSession) {
        let evaluation = attentionEvaluator.evaluate(session: session, owningDay: owningDayDate(for: session))
        if evaluation.shouldShowRecoveryPrompt {
            recoveryPromptSession = session
        } else {
            onResumeRoute(sessionResumePlanner.resumeRoute(for: session) ?? sessionResumePlanner.openRoute(for: session))
        }
    }

    private func finish(_ session: WorkoutSession) {
        withAnimation(.workoutAdaptive(reducedMotion: accessibilityReduceMotion)) {
            if session.isPaused {
                session.resume()
            }
            session.endedAt = Date()
            session.status = .completed

            do {
                try modelContext.save()
            } catch {
                assertionFailure("Failed to finish active session from Home: \(error)")
            }
        }
    }
}

private struct ActiveSessionCard: View {
    let session: WorkoutSession
    let isPastDay: Bool
    let attentionState: SessionAttentionState
    let subtitle: String
    let resumeAccessibilityID: String
    let finishAccessibilityID: String?
    let cardAccessibilityID: String
    let resumeAction: () -> Void
    let finishAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isStale: Bool {
        switch attentionState {
        case .fresh:
            return false
        case .staleSuppressed, .staleNeedsPrompt:
            return true
        }
    }

    private var badgeTitle: String {
        isStale ? AppFormatting.localized("Previous day") : AppFormatting.localized("Today")
    }

    private var badgeForeground: Color {
        isStale ? .orange : .green
    }

    private var stacksButtons: Bool {
        AdaptiveLayoutMetrics.shouldStackActiveSessionButtons(dynamicTypeSize: dynamicTypeSize)
    }

    private var stacksHeader: Bool {
        AdaptiveLayoutMetrics.shouldStackActiveSessionCardHeader(dynamicTypeSize: dynamicTypeSize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if stacksHeader {
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock
                    badgeView
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    titleBlock
                    Spacer(minLength: 8)
                    badgeView
                }
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if attentionState == .staleNeedsPrompt {
                Label(String(localized: "session.attention.needs_attention"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if stacksButtons {
                VStack(alignment: .leading, spacing: 10) {
                    resumeButton
                    if isPastDay { finishButton }
                }
            } else {
                HStack(spacing: 10) {
                    resumeButton
                    if isPastDay { finishButton }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
        .shadow(radius: 10, y: 6)
        .accessibilityCardSummary(
            label: session.sourceRoutineNameSnapshot ?? String(localized: "Workout"),
            value: AccessibilityLabels.Home.cardValue(
                subtitle: subtitle,
                badgeTitle: badgeTitle,
                needsAttention: attentionState == .staleNeedsPrompt
            ),
            identifier: cardAccessibilityID
        )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.sourceRoutineNameSnapshot ?? AppFormatting.localized("Workout session"))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            if session.isPaused {
                Text(AppFormatting.localized("Paused"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var badgeView: some View {
        Text(badgeTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeForeground.opacity(0.15), in: Capsule())
            .accessibilityHidden(true)
    }

    private var resumeButton: some View {
        Button(action: resumeAction) {
            Label(AccessibilityLabels.Buttons.resumeWorkout, systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint(AccessibilityLabels.Buttons.resumeWorkoutHint)
        .accessibilityIdentifier(resumeAccessibilityID)
    }

    private var finishButton: some View {
        Button(role: .destructive, action: finishAction) {
            Label(AccessibilityLabels.Buttons.finishNow, systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityHint(AccessibilityLabels.Buttons.finishNowHint)
        .accessibilityIdentifier(finishAccessibilityID ?? "Home.ActiveSessions.Finish")
    }
}
