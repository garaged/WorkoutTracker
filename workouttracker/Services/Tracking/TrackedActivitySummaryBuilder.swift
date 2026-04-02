import Foundation

struct TrackedActivitySummaryBuilder {
    struct Metric: Identifiable, Equatable {
        enum Kind: String {
            case duration
            case distance
            case averagePace
            case activeEnergy
            case stepCount
            case state
        }

        let kind: Kind
        let title: String
        let value: String

        var id: String { kind.rawValue }
    }

    func metrics(for session: TrackedActivitySession, now: Date = Date()) -> [Metric] {
        metrics(for: session.activityKind, totals: session.liveTotals(at: now), lifecycleState: session.lifecycleState)
    }

    func metrics(for summary: TrackedActivitySummary) -> [Metric] {
        metrics(for: summary.activityKind, totals: summary.totals, lifecycleState: summary.lifecycleState)
    }

    func metrics(
        for activityKind: TrackedActivityKind,
        totals: TrackedActivityTotals,
        lifecycleState: TrackedActivityLifecycleState
    ) -> [Metric] {
        var values: [Metric] = [
            Metric(kind: .duration, title: "Duration", value: Self.formatDuration(totals.elapsedDuration)),
            Metric(kind: .state, title: "Status", value: lifecycleState.displayName)
        ]

        if activityKind.supportsDistance,
           let distanceMeters = totals.distanceMeters,
           distanceMeters > 0 {
            values.append(
                Metric(kind: .distance, title: "Distance", value: Self.formatDistance(distanceMeters))
            )
        }

        if activityKind.supportsPace,
           let distanceMeters = totals.distanceMeters,
           distanceMeters > 0,
           totals.elapsedDuration > 0 {
            let paceSecondsPerKilometer = totals.elapsedDuration / (distanceMeters / 1_000)
            values.append(
                Metric(kind: .averagePace, title: "Average pace", value: Self.formatPace(paceSecondsPerKilometer))
            )
        }

        if let activeEnergy = totals.activeEnergyKilocalories,
           activeEnergy > 0 {
            values.append(
                Metric(kind: .activeEnergy, title: "Active energy", value: Self.formatEnergy(activeEnergy))
            )
        }

        if activityKind.supportsSteps,
           let stepCount = totals.stepCount,
           stepCount > 0 {
            values.append(
                Metric(kind: .stepCount, title: "Steps", value: Self.formatSteps(stepCount))
            )
        }

        return values
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ distanceMeters: Double) -> String {
        let kilometers = distanceMeters / 1_000
        let formatted = kilometers.formatted(.number.precision(.fractionLength(kilometers < 10 ? 2 : 1)))
        return "\(formatted) km"
    }

    static func formatEnergy(_ activeEnergyKilocalories: Double) -> String {
        "\(Int(activeEnergyKilocalories.rounded())) kcal"
    }

    static func formatSteps(_ stepCount: Int) -> String {
        "\(stepCount.formatted()) steps"
    }

    static func formatPace(_ paceSecondsPerKilometer: Double) -> String {
        let roundedSeconds = max(0, Int(paceSecondsPerKilometer.rounded()))
        let minutes = roundedSeconds / 60
        let seconds = roundedSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

private extension TrackedActivityLifecycleState {
    var displayName: String {
        switch self {
        case .planned:
            return "Planned"
        case .inProgress:
            return "In progress"
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .discarded:
            return "Discarded"
        }
    }
}
