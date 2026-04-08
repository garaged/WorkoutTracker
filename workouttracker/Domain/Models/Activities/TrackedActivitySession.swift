import Foundation
import SwiftData
import CoreLocation

@Model
final class TrackedActivitySession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var startedAt: Date?
    var endedAt: Date?
    var activeIntervalStartedAt: Date?

    var activityKindRaw: String
    var environmentRaw: String
    var lifecycleStateRaw: String
    var healthKitExportStateRaw: String

    var elapsedDuration: TimeInterval
    var distanceMeters: Double?
    var activeEnergyKilocalories: Double?
    var stepCount: Int?

    var routePointsBlob: Data?
    var routePointCount: Int

    var linkedActivityId: UUID?
    var notes: String?

    var healthKitExportAttemptedAt: Date?
    var healthKitExportSucceededAt: Date?
    var healthKitExportFailureMessage: String?
    var hasLocalChangesSinceHealthKitExport: Bool
    
    var healthKitRouteAttachmentStateRaw: String
    var healthKitRouteAttachmentFailureMessage: String?
    var healthKitRouteAttachmentUpdatedAt: Date?

    var lastResumedAt: Date?
    var lastBackgroundedAt: Date?
    var dismissedRecoveryPromptAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        activeIntervalStartedAt: Date? = nil,
        activityKind: TrackedActivityKind,
        environment: ActivityEnvironment = .unspecified,
        lifecycleState: TrackedActivityLifecycleState = .planned,
        totals: TrackedActivityTotals = TrackedActivityTotals(elapsedDuration: 0),
        healthKitExportState: HealthKitExportState = .notRequested,
        routePoints: [TrackedActivityRoutePoint] = [],
        linkedActivityId: UUID? = nil,
        notes: String? = nil,
        healthKitExportAttemptedAt: Date? = nil,
        healthKitExportSucceededAt: Date? = nil,
        healthKitExportFailureMessage: String? = nil,
        hasLocalChangesSinceHealthKitExport: Bool = false,
        lastResumedAt: Date? = nil,
        lastBackgroundedAt: Date? = nil,
        dismissedRecoveryPromptAt: Date? = nil,
        healthKitRouteAttachmentState: HealthKitRouteAttachmentState = .unknown,
        healthKitRouteAttachmentFailureMessage: String? = nil,
        healthKitRouteAttachmentUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activeIntervalStartedAt = activeIntervalStartedAt
        self.activityKindRaw = activityKind.rawValue
        self.environmentRaw = environment.rawValue
        self.lifecycleStateRaw = lifecycleState.rawValue
        self.healthKitExportStateRaw = healthKitExportState.rawValue
        self.elapsedDuration = max(0, totals.elapsedDuration)
        self.distanceMeters = totals.distanceMeters
        self.activeEnergyKilocalories = totals.activeEnergyKilocalories
        self.stepCount = totals.stepCount
        self.routePointsBlob = Self.encodeRoutePoints(routePoints)
        self.routePointCount = routePoints.count
        self.linkedActivityId = linkedActivityId
        self.notes = notes
        self.healthKitExportAttemptedAt = healthKitExportAttemptedAt
        self.healthKitExportSucceededAt = healthKitExportSucceededAt
        self.healthKitExportFailureMessage = healthKitExportFailureMessage
        self.hasLocalChangesSinceHealthKitExport = hasLocalChangesSinceHealthKitExport
        self.lastResumedAt = lastResumedAt
        self.lastBackgroundedAt = lastBackgroundedAt
        self.dismissedRecoveryPromptAt = dismissedRecoveryPromptAt
        self.healthKitRouteAttachmentStateRaw = healthKitRouteAttachmentState.rawValue
        self.healthKitRouteAttachmentFailureMessage = healthKitRouteAttachmentFailureMessage
        self.healthKitRouteAttachmentUpdatedAt = healthKitRouteAttachmentUpdatedAt

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
    
    var healthKitRouteAttachmentState: HealthKitRouteAttachmentState {
        get { HealthKitRouteAttachmentState(rawValue: healthKitRouteAttachmentStateRaw) ?? .unknown }
        set {
            healthKitRouteAttachmentStateRaw = newValue.rawValue
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

    var routePoints: [TrackedActivityRoutePoint] {
        get { Self.decodeRoutePoints(routePointsBlob) }
        set {
            routePointsBlob = Self.encodeRoutePoints(newValue)
            routePointCount = newValue.count
            touch()
        }
    }

    var hasRecordedRoute: Bool {
        routePointCount > 1
    }

    var routeDistanceMeters: Double? {
        let points = routePoints
        guard points.count > 1 else { return nil }

        let locations = points.map(\.location)
        var distance: CLLocationDistance = 0
        for index in 1..<locations.count {
            distance += max(0, locations[index].distance(from: locations[index - 1]))
        }
        return distance > 0 ? distance : nil
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

    var isCompletedButNotSavedToHealthKit: Bool {
        lifecycleState == .completed && healthKitExportState != .exported
    }

    func setTotals(_ totals: TrackedActivityTotals) {
        self.totals = totals
    }

    func start(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        activeIntervalStartedAt = date
        lastResumedAt = date
        dismissedRecoveryPromptAt = nil
        lifecycleStateRaw = TrackedActivityLifecycleState.inProgress.rawValue
        if environment == .unspecified {
            environmentRaw = activityKind.defaultEnvironment.rawValue
        }
        updatedAt = date
    }

    func pause(at date: Date = Date()) {
        accumulateElapsedIfNeeded(until: date)
        activeIntervalStartedAt = nil
        lifecycleStateRaw = TrackedActivityLifecycleState.paused.rawValue
        updatedAt = date
    }

    func resume(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        activeIntervalStartedAt = date
        lastResumedAt = date
        dismissedRecoveryPromptAt = nil
        lifecycleStateRaw = TrackedActivityLifecycleState.inProgress.rawValue
        updatedAt = date
    }

    func complete(at date: Date = Date()) {
        if startedAt == nil {
            startedAt = date
        }
        accumulateElapsedIfNeeded(until: date)
        activeIntervalStartedAt = nil
        endedAt = endedAt ?? date
        dismissedRecoveryPromptAt = nil
        lifecycleStateRaw = TrackedActivityLifecycleState.completed.rawValue
        updatedAt = date
    }

    func discard(at date: Date = Date()) {
        accumulateElapsedIfNeeded(until: date)
        activeIntervalStartedAt = nil
        lifecycleStateRaw = TrackedActivityLifecycleState.discarded.rawValue
        endedAt = endedAt ?? date
        dismissedRecoveryPromptAt = nil
        updatedAt = date
    }

    func markRecoveryOpened(at date: Date = Date()) {
        guard lifecycleState == .inProgress || lifecycleState == .paused else { return }
        lastResumedAt = date
        dismissedRecoveryPromptAt = nil
        updatedAt = date
    }

    func markBackgrounded(at date: Date = Date()) {
        guard lifecycleState == .inProgress || lifecycleState == .paused else { return }
        lastBackgroundedAt = date
        updatedAt = date
    }

    func keepForLater(at date: Date = Date()) {
        guard lifecycleState == .inProgress || lifecycleState == .paused else { return }
        dismissedRecoveryPromptAt = date
        updatedAt = date
    }

    func markHealthKitExportPending(at date: Date = Date()) {
        healthKitExportStateRaw = HealthKitExportState.pending.rawValue
        healthKitExportAttemptedAt = date
        healthKitExportFailureMessage = nil
        healthKitRouteAttachmentStateRaw = HealthKitRouteAttachmentState.unknown.rawValue
        healthKitRouteAttachmentFailureMessage = nil
        healthKitRouteAttachmentUpdatedAt = date
        updatedAt = date
    }

    func markHealthKitExportSucceeded(at date: Date = Date()) {
        healthKitExportStateRaw = HealthKitExportState.exported.rawValue
        healthKitExportAttemptedAt = date
        healthKitExportSucceededAt = date
        healthKitExportFailureMessage = nil
        hasLocalChangesSinceHealthKitExport = false
        updatedAt = date
    }

    func markHealthKitExportFailed(
        state: HealthKitExportState = .failed,
        message: String?,
        at date: Date = Date()
    ) {
        healthKitExportStateRaw = state.rawValue
        healthKitExportAttemptedAt = date
        healthKitExportFailureMessage = message
        updatedAt = date
    }

    func markLocalChangesSinceHealthKitExport(at date: Date = Date()) {
        guard healthKitExportState == .exported else {
            updatedAt = date
            return
        }
        hasLocalChangesSinceHealthKitExport = true
        updatedAt = date
    }
    
    func markHealthKitRouteAttachment(
        state: HealthKitRouteAttachmentState,
        message: String? = nil,
        at date: Date = Date()
    ) {
        healthKitRouteAttachmentStateRaw = state.rawValue
        healthKitRouteAttachmentFailureMessage = message
        healthKitRouteAttachmentUpdatedAt = date
        updatedAt = date
    }

    func liveElapsedDuration(at date: Date = Date()) -> TimeInterval {
        switch lifecycleState {
        case .inProgress:
            let anchor = activeIntervalStartedAt ?? startedAt ?? updatedAt
            return max(0, elapsedDuration + max(0, date.timeIntervalSince(anchor)))
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

        if lifecycleState == .inProgress && activeIntervalStartedAt == nil {
            activeIntervalStartedAt = startedAt ?? updatedAt
        }

        if lifecycleState != .inProgress {
            activeIntervalStartedAt = nil
        }

        if lifecycleState == .completed && endedAt == nil {
            endedAt = startedAt ?? updatedAt
        }

        if lifecycleState == .discarded && endedAt == nil {
            endedAt = updatedAt
        }

        if lifecycleState == .inProgress || lifecycleState == .paused {
            if lastResumedAt == nil {
                lastResumedAt = startedAt ?? updatedAt
            }
        }

        if lifecycleState == .completed || lifecycleState == .discarded {
            dismissedRecoveryPromptAt = nil
        }

        if healthKitExportState == .exported {
            healthKitExportFailureMessage = nil
        }
    }

    private func accumulateElapsedIfNeeded(until date: Date) {
        guard lifecycleState == .inProgress else { return }
        let anchor = activeIntervalStartedAt ?? startedAt ?? updatedAt
        elapsedDuration = max(0, elapsedDuration + max(0, date.timeIntervalSince(anchor)))
    }

    private static func encodeRoutePoints(_ points: [TrackedActivityRoutePoint]) -> Data? {
        guard !points.isEmpty else { return nil }
        return try? JSONEncoder().encode(points)
    }

    private static func decodeRoutePoints(_ data: Data?) -> [TrackedActivityRoutePoint] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([TrackedActivityRoutePoint].self, from: data)) ?? []
    }
}

enum HealthKitRouteAttachmentState: String, Codable {
    case unknown
    case notApplicable
    case noRouteData
    case attached
    case failed
}
