import Foundation

/// Stable summary payload consumed by finish/history/progress layers later.
struct TrackedActivitySummary: Equatable, Codable, Sendable {
    enum HighlightMetricKind: String, Codable, CaseIterable, Sendable {
        case duration
        case distance
        case averagePace
        case activeEnergy
        case stepCount
    }

    let sessionID: UUID
    let activityKind: TrackedActivityKind
    let environment: ActivityEnvironment
    let lifecycleState: TrackedActivityLifecycleState
    let startedAt: Date?
    let endedAt: Date?
    let totals: TrackedActivityTotals
    let healthKitExportState: HealthKitExportState

    var averagePaceSecondsPerKilometer: Double? {
        guard activityKind.supportsPace,
              let distanceMeters = totals.distanceMeters,
              distanceMeters > 0 else {
            return nil
        }

        let kilometers = distanceMeters / 1_000
        guard kilometers > 0 else { return nil }
        return totals.elapsedDuration / kilometers
    }

    var highlightedMetricKinds: [HighlightMetricKind] {
        var metrics: [HighlightMetricKind] = [.duration]

        switch activityKind {
        case .walking, .hiking:
            if totals.hasDistance { metrics.append(.distance) }
            if let stepCount = totals.stepCount, stepCount > 0 { metrics.append(.stepCount) }
            if let activeEnergy = totals.activeEnergyKilocalories, activeEnergy > 0 {
                metrics.append(.activeEnergy)
            }

        case .running:
            if totals.hasDistance { metrics.append(.distance) }
            if averagePaceSecondsPerKilometer != nil { metrics.append(.averagePace) }
            if let activeEnergy = totals.activeEnergyKilocalories, activeEnergy > 0 {
                metrics.append(.activeEnergy)
            }
            if let stepCount = totals.stepCount, stepCount > 0 { metrics.append(.stepCount) }

        case .yoga:
            if let activeEnergy = totals.activeEnergyKilocalories, activeEnergy > 0 {
                metrics.append(.activeEnergy)
            }
        }

        return metrics
    }
}
