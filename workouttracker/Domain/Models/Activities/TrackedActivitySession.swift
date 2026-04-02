import Foundation
import SwiftData

@Model
final class TrackedActivitySession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var startedAt: Date?
    var endedAt: Date?

    var activityKindRaw: String
    var environmentRaw: String
    var lifecycleStateRaw: String
    var healthKitExportStateRaw: String

    var elapsedDuration: TimeInterval
    var distanceMeters: Double?
    var activeEnergyKilocalories: Double?
    var stepCount: Int?

    var linkedActivityId: UUID?
    var notes: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        activityKind: TrackedActivityKind,
        environment: ActivityEnvironment = .unspecified,
        lifecycleState: TrackedActivityLifecycleState = .planned,
        totals: TrackedActivityTotals = TrackedActivityTotals(elapsedDuration: 0),
        healthKitExportState: HealthKitExportState = .notRequested,
        linkedActivityId: UUID? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activityKindRaw = activityKind.rawValue
        self.environmentRaw = environment.rawValue
        self.lifecycleStateRaw = lifecycleState.rawValue
        self.healthKitExportStateRaw = healthKitExportState.rawValue
        self.elapsedDuration = max(0, totals.elapsedDuration)
        self.distanceMeters = totals.distanceMeters
        self.activeEnergyKilocalories = totals.activeEnergyKilocalories
        self.stepCount = totals.stepCount
        self.linkedActivityId = linkedActivityId
        self.notes = notes

        normalizeLifecycleConsistency()
    }

    var activityKind: TrackedActivityKind {
        get { TrackedActivityKind(rawValue: activityKindRaw) ?? .walking }
        set {
            activityKindRaw = newValue.rawValue
            touch()
        }
    }

    var environment: ActivityEnvironment {
        get { ActivityEnvironment(rawValue: environmentRaw) ?? .unspecified }
        set {
            environmentRaw = newValue.rawValue
            touch()
        }
    }

    var lifecycleState: TrackedActivityLifecycleState {
        get { TrackedActivityLifecycleState(rawValue: lifecycleStateRaw) ?? .planned }
        set {
            lifecycleStateRaw = newValue.rawValue
            normalizeLifecycleConsistency()
            touch()
        }
    }

    var healthKitExportState: HealthKitExportState {
        get { HealthKitExportState(rawValue: healthKitExportStateRaw) ?? .notRequested }
        set {
            healthKitExportStateRaw = newValue.rawValue
            touch()
        }
    }

    var totals: TrackedActivityTotals {
        get {
            TrackedActivityTotals(
                elapsedDuration: elapsedDuration,
                distanceMeters: distanceMeters,
                activeEnergyKilocalories: activeEnergyKilocalories,
                stepCount: stepCount
            )
        }
        set {
            elapsedDuration = max(0, newValue.elapsedDuration)
            distanceMeters = newValue.distanceMeters
            activeEnergyKilocalories = newValue.activeEnergyKilocalories
            stepCount = newValue.stepCount
            touch()
        }
    }

    var summary: TrackedActivitySummary {
        TrackedActivitySummary(
            sessionID: id,
            activityKind: activityKind,
            environment: environment,
            lifecycleState: lifecycleState,
            startedAt: startedAt,
            endedAt: endedAt,
            totals: totals,
            healthKitExportState: healthKitExportState
        )
    }

    var isActive: Bool {
        switch lifecycleState {
        case .inProgress, .paused:
            return true
        case .planned, .completed, .discarded:
            return false
        }
    }

    func setTotals(_ totals: TrackedActivityTotals) {
        self.totals = totals
    }

    func start(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        lifecycleStateRaw = TrackedActivityLifecycleState.inProgress.rawValue
        if environment == .unspecified {
            environmentRaw = activityKind.defaultEnvironment.rawValue
        }
        updatedAt = date
    }

    func pause(at date: Date = Date()) {
        accumulateElapsedIfNeeded(until: date)
        lifecycleStateRaw = TrackedActivityLifecycleState.paused.rawValue
        updatedAt = date
    }

    func resume(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        lifecycleStateRaw = TrackedActivityLifecycleState.inProgress.rawValue
        updatedAt = date
    }

    func complete(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        accumulateElapsedIfNeeded(until: date)
        endedAt = endedAt ?? date
        lifecycleStateRaw = TrackedActivityLifecycleState.completed.rawValue
        updatedAt = date
    }

    func discard(at date: Date = Date()) {
        accumulateElapsedIfNeeded(until: date)
        lifecycleStateRaw = TrackedActivityLifecycleState.discarded.rawValue
        endedAt = endedAt ?? date
        updatedAt = date
    }

    func liveElapsedDuration(at date: Date = Date()) -> TimeInterval {
        switch lifecycleState {
        case .inProgress:
            return max(0, elapsedDuration + max(0, date.timeIntervalSince(updatedAt)))
        case .planned, .paused, .completed, .discarded:
            return max(0, elapsedDuration)
        }
    }

    func liveTotals(at date: Date = Date()) -> TrackedActivityTotals {
        var totals = self.totals
        totals.elapsedDuration = liveElapsedDuration(at: date)
        return totals
    }

    private func touch(at date: Date = Date()) {
        updatedAt = date
    }

    private func normalizeLifecycleConsistency() {
        elapsedDuration = max(0, elapsedDuration)

        if lifecycleState == .completed && endedAt == nil {
            endedAt = startedAt ?? updatedAt
        }

        if lifecycleState == .discarded && endedAt == nil {
            endedAt = updatedAt
        }
    }

    private func accumulateElapsedIfNeeded(until date: Date) {
        guard lifecycleState == .inProgress else { return }
        elapsedDuration = max(0, elapsedDuration + max(0, date.timeIntervalSince(updatedAt)))
    }
}
