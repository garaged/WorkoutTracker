import Foundation
import SwiftData

@MainActor
struct TrackedActivityRecorder {
    func createSession(
        activityKind: TrackedActivityKind,
        environment: ActivityEnvironment,
        notes: String? = nil,
        context: ModelContext,
        at date: Date = Date()
    ) throws -> TrackedActivitySession {
        let normalizedEnvironment = environment == .unspecified ? activityKind.defaultEnvironment : environment
        let session = TrackedActivitySession(
            createdAt: date,
            updatedAt: date,
            startedAt: date,
            endedAt: nil,
            activityKind: activityKind,
            environment: normalizedEnvironment,
            lifecycleState: .inProgress,
            totals: TrackedActivityTotals(elapsedDuration: 0),
            notes: normalize(notes)
        )

        context.insert(session)
        try context.save()
        return session
    }

    func pause(_ session: TrackedActivitySession, context: ModelContext, at date: Date = Date()) throws {
        guard session.lifecycleState == .inProgress else { return }
        session.pause(at: date)
        try context.save()
    }

    func resume(_ session: TrackedActivitySession, context: ModelContext, at date: Date = Date()) throws {
        guard session.lifecycleState == .paused || session.lifecycleState == .planned else { return }
        session.resume(at: date)
        try context.save()
    }

    func complete(_ session: TrackedActivitySession, context: ModelContext, at date: Date = Date()) throws {
        guard !session.lifecycleState.isTerminal else { return }
        session.complete(at: date)
        try context.save()
    }

    func discard(_ session: TrackedActivitySession, context: ModelContext, at date: Date = Date()) throws {
        guard !session.lifecycleState.isTerminal else { return }
        session.discard(at: date)
        try context.save()
    }

    func updateSummaryValues(
        for session: TrackedActivitySession,
        distanceMeters: Double?,
        activeEnergyKilocalories: Double?,
        stepCount: Int?,
        notes: String?,
        context: ModelContext,
        at date: Date = Date()
    ) throws {
        let sanitizedDistance: Double? = {
            guard session.activityKind.supportsDistance else { return nil }
            guard let distanceMeters, distanceMeters > 0 else { return nil }
            return distanceMeters
        }()

        let sanitizedStepCount: Int? = {
            guard session.activityKind.supportsSteps else { return nil }
            guard let stepCount, stepCount > 0 else { return nil }
            return stepCount
        }()

        let sanitizedEnergy: Double? = {
            guard let activeEnergyKilocalories, activeEnergyKilocalories > 0 else { return nil }
            return activeEnergyKilocalories
        }()

        session.distanceMeters = sanitizedDistance
        session.activeEnergyKilocalories = sanitizedEnergy
        session.stepCount = sanitizedStepCount
        session.notes = normalize(notes)
        session.updatedAt = date
        try context.save()
    }

    func updateCapturedRoute(
        for session: TrackedActivitySession,
        routePoints: [TrackedActivityRoutePoint],
        derivedDistanceMeters: Double?,
        context: ModelContext,
        at date: Date = Date()
    ) throws {
        guard session.activityKind.supportsDistance, session.environment == .outdoor else { return }

        session.routePoints = routePoints
        if let derivedDistanceMeters, derivedDistanceMeters > 0 {
            session.distanceMeters = max(session.distanceMeters ?? 0, derivedDistanceMeters)
        }
        session.updatedAt = date
        try context.save()
    }

    func updateHealthKitExportState(
        for session: TrackedActivitySession,
        state: HealthKitExportState,
        context: ModelContext,
        at date: Date = Date()
    ) throws {
        session.healthKitExportState = state
        session.updatedAt = date
        try context.save()
    }

    func liveTotals(for session: TrackedActivitySession, now: Date = Date()) -> TrackedActivityTotals {
        session.liveTotals(at: now)
    }

    private func normalize(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
