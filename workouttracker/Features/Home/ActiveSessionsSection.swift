import SwiftUI
import SwiftData

struct ActiveSessionsSection: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)])
    private var sessions: [WorkoutSession]

    @Query
    private var activities: [Activity]

    private let calendar = Calendar.current

    private var activityByID: [UUID: Activity] {
        Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
    }

    private var activeSessions: [WorkoutSession] {
        sessions
            .filter { $0.status == .inProgress && $0.endedAt == nil }
            .sorted(by: activeSessionSort)
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
                Label("Active Sessions", systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)

                Spacer()

                Text("\(activeSessions.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("Resume unfinished workouts here. Sessions from previous days can be finished quickly so they stop appearing on Home.")
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

    private func activeSessionSort(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        let lhsOwningDay = calendar.startOfDay(for: owningDayDate(for: lhs))
        let rhsOwningDay = calendar.startOfDay(for: owningDayDate(for: rhs))

        let lhsToday = calendar.isDateInToday(lhsOwningDay)
        let rhsToday = calendar.isDateInToday(rhsOwningDay)

        if lhsToday != rhsToday {
            return lhsToday && !rhsToday
        }

        if lhsOwningDay != rhsOwningDay {
            return lhsOwningDay > rhsOwningDay
        }

        return lhs.startedAt > rhs.startedAt
    }

    private func isPastDay(_ session: WorkoutSession) -> Bool {
        let todayStart = calendar.startOfDay(for: Date())
        return calendar.startOfDay(for: owningDayDate(for: session)) < todayStart
    }

    private func subtitle(for session: WorkoutSession) -> String {
        let startedText: String
        if calendar.isDateInToday(session.startedAt) {
            startedText = "Started today at \(session.startedAt.formatted(date: .omitted, time: .shortened))"
        } else {
            startedText = "Started \(session.startedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        let plannedPrefix: String? = {
            guard let activity = linkedActivity(for: session) else { return nil }
            guard !calendar.isDate(activity.startAt, inSameDayAs: session.startedAt) else { return nil }

            if calendar.isDateInToday(activity.startAt) {
                return "Planned for today"
            } else if calendar.isDateInYesterday(activity.startAt) {
                return "Planned for yesterday"
            } else {
                return "Planned for \(activity.startAt.formatted(date: .abbreviated, time: .omitted))"
            }
        }()

        let base = plannedPrefix.map { "\($0) · \(startedText)" } ?? startedText

        if session.isPaused {
            return "Paused · \(base)"
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
    let finishAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sourceRoutineNameSnapshot ?? "Workout")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isPastDay {
                    Text("Previous day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())
                } else {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                NavigationLink {
                    WorkoutSessionScreen(session: session)
                } label: {
                    Label("Resume", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Home.ActiveSessions.Resume")

                if isPastDay {
                    Button(action: finishAction) {
                        Label("Finish", systemImage: "checkmark.circle")
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
