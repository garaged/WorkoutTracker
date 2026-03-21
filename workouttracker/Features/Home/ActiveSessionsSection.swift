import SwiftUI
import SwiftData

struct ActiveSessionsSection: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query
    private var activities: [Activity]

    var onResume: (WorkoutSession) -> Void = { _ in }

    private let calendar = Calendar.current
    private let sessionResumePlanner = SessionResumePlanner()

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
                    ActiveSessionCard(
                        session: session,
                        isPastDay: isPastDay(session),
                        subtitle: subtitle(for: session),
                        resumeAction: { onResume(session) },
                        finishAction: { finish(session) }
                    )
                }
            }
            .accessibilityIdentifier("Home.ActiveSessions.Section")
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

            Text(AppFormatting.localized("Resume unfinished workouts here. Sessions from previous days can be finished quickly so they stop appearing on Home."))
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
    let subtitle: String
    let resumeAction: () -> Void
    let finishAction: () -> Void

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

                if isPastDay {
                    Text(AppFormatting.localized("Previous day"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())
                } else {
                    Text(AppFormatting.localized("Today"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                Button(action: resumeAction) {
                    Label(AppFormatting.localized("Resume"), systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Home.ActiveSessions.Resume")

                if isPastDay {
                    Button(action: finishAction) {
                        Label(AppFormatting.localized("Finish"), systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("Home.ActiveSessions.Finish")
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
    }
}
