import SwiftUI
import SwiftData

struct ActiveSessionsSection: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query
    private var activities: [Activity]

    @State private var recoveryPromptSession: WorkoutSession? = nil

    var onResume: (WorkoutSession) -> Void = { _ in }

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
                    )                }
            }
            .accessibilityIdentifier("Home.ActiveSessions.Section")
            .sheet(item: $recoveryPromptSession) { session in
                SessionRecoveryPrompt(
                    title: String(localized: "Older unfinished workout"),
                    message: recoveryPromptMessage(for: session),
                    onResume: {
                        do {
                            try WorkoutSessionStarter.resumeForActiveLogging(session, context: modelContext)
                            recoveryPromptSession = nil
                            onResume(session)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(AppFormatting.localized("Active Sessions"), systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)

                Spacer()

                Text("\(activeSessions.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(AppFormatting.localized("Resume unfinished workouts here. Previous-day sessions stay visible, but recovery choices appear only when you open them."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func linkedActivity(for session: WorkoutSession) -> Activity? {
        guard let id = session.linkedActivityId else { return nil }
        return activityByID[id]
    }

    /// The day this session *belongs to*.
    /// Prefer the linked workout activity date; fall back to when the session record was started.
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
            format: String(localized: "This unfinished workout belongs to %@. Resume it now, finish it, discard it, or keep it for later without being prompted again today."),
            locale: .autoupdatingCurrent,
            dayText
        )
    }

    private func handleResumeTap(for session: WorkoutSession) {
        let evaluation = attentionEvaluator.evaluate(session: session, owningDay: owningDayDate(for: session))
        if evaluation.shouldShowRecoveryPrompt {
            recoveryPromptSession = session
        } else {
            onResume(session)
        }
    }
    
    private func finish(_ session: WorkoutSession) {
            withAnimation(.snappy) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sourceRoutineNameSnapshot ?? String(localized: "Workout"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badgeTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(badgeForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeForeground.opacity(0.12), in: Capsule())
            }
            
            if attentionState == .staleNeedsPrompt {
                Text(AppFormatting.localized("Needs attention"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            HStack(alignment: .top, spacing: 10) {
                Button(action: resumeAction) {
                    Label(AppFormatting.localized("Resume"), systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(resumeAccessibilityID)
                
                if isPastDay {
                    Button(action: finishAction) {
                        Label(AppFormatting.localized("Finish"), systemImage:  "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(finishAccessibilityID ?? "Home.ActiveSessions.Finish")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
        .shadow(radius: 10, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(cardAccessibilityID)
    }
}
