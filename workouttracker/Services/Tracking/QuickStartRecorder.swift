import Foundation
import SwiftData

@MainActor
struct QuickStartRecorder {
    enum RecordingError: Error, Equatable {
        case pendingChanges
        case activeSessionConflict([UUID])
        case identityConflict
        case invalidRecord
    }

    var save: (ModelContext) throws -> Void = { try $0.save() }

    func start(style: QuickStartStyle, id: UUID, at clock: QuickStartClockSample,
               context: ModelContext) throws -> TrackedActivitySession {
        try requireClean(context)
        let tracked = try context.fetch(FetchDescriptor<TrackedActivitySession>())
        if let existing = tracked.first(where: { $0.id == id }) {
            let payload = try readPayload(existing)
            guard payload.styleRaw == style.rawValue else { throw RecordingError.identityConflict }
            return existing
        }
        let strength = try context.fetch(FetchDescriptor<WorkoutSession>())
        let activeIDs = (tracked.filter(\.isActive).map(\.id) + strength.filter(\.isUnfinished).map(\.id))
            .sorted { $0.uuidString < $1.uuidString }
        guard activeIDs.isEmpty else { throw RecordingError.activeSessionConflict(activeIDs) }

        let timing = try QuickStartTimingState().applying(.start, id: id, expectedRevision: 0, at: clock)
        let encoded = try JSONEncoder().encode(QuickStartTimingPayload(styleRaw: style.rawValue, timing: timing))
        let session = TrackedActivitySession(id: id, createdAt: clock.wall, updatedAt: clock.wall,
            startedAt: clock.wall, activeIntervalStartedAt: clock.wall, activityKind: .generic,
            environment: .unspecified, lifecycleState: .inProgress, lastResumedAt: clock.wall)
        session.quickStartTimingBlob = encoded
        context.insert(session)
        do { try save(context) }
        catch {
            context.rollback()
            throw error
        }
        return session
    }

    func apply(_ action: QuickStartTimingState.Action, to session: TrackedActivitySession,
               id: UUID, expectedRevision: Int, at clock: QuickStartClockSample,
               context: ModelContext) throws {
        try requireClean(context)
        guard session.modelContext === context, session.lifecycleState != .discarded else {
            throw RecordingError.invalidRecord
        }
        let payload = try readPayload(session)
        let next = try payload.timing.applying(action, id: id, expectedRevision: expectedRevision, at: clock)
        guard next != payload.timing else { return }
        let encoded = try JSONEncoder().encode(QuickStartTimingPayload(styleRaw: payload.styleRaw, timing: next))
        let committed = CommittedFields(session)
        session.quickStartTimingBlob = encoded
        session.elapsedDuration = next.accumulated
        session.activeIntervalStartedAt = next.anchor?.wall
        session.updatedAt = clock.wall
        switch next.phase {
        case .idle: throw RecordingError.invalidRecord
        case .running:
            session.lifecycleStateRaw = TrackedActivityLifecycleState.inProgress.rawValue
            session.lastResumedAt = clock.wall
            session.dismissedRecoveryPromptAt = nil
        case .paused:
            session.lifecycleStateRaw = TrackedActivityLifecycleState.paused.rawValue
        case .completed:
            session.lifecycleStateRaw = TrackedActivityLifecycleState.completed.rawValue
            session.endedAt = session.endedAt ?? clock.wall
            session.dismissedRecoveryPromptAt = nil
        }
        do { try save(context) }
        catch {
            committed.restore(session)
            context.rollback()
            throw error
        }
    }

    private func requireClean(_ context: ModelContext) throws {
        guard !context.hasChanges else { throw RecordingError.pendingChanges }
    }

    private func readPayload(_ session: TrackedActivitySession) throws -> QuickStartTimingPayload {
        guard let data = session.quickStartTimingBlob, session.activityKind == .generic else {
            throw RecordingError.invalidRecord
        }
        return try JSONDecoder().decode(QuickStartTimingPayload.self, from: data)
    }

    private struct CommittedFields {
        let quickStartTimingBlob: Data?
        let elapsedDuration: TimeInterval
        let activeIntervalStartedAt: Date?
        let updatedAt: Date
        let lifecycleStateRaw: String
        let lastResumedAt: Date?
        let dismissedRecoveryPromptAt: Date?
        let endedAt: Date?

        init(_ session: TrackedActivitySession) {
            quickStartTimingBlob = session.quickStartTimingBlob
            elapsedDuration = session.elapsedDuration
            activeIntervalStartedAt = session.activeIntervalStartedAt
            updatedAt = session.updatedAt
            lifecycleStateRaw = session.lifecycleStateRaw
            lastResumedAt = session.lastResumedAt
            dismissedRecoveryPromptAt = session.dismissedRecoveryPromptAt
            endedAt = session.endedAt
        }

        func restore(_ session: TrackedActivitySession) {
            session.quickStartTimingBlob = quickStartTimingBlob
            session.elapsedDuration = elapsedDuration
            session.activeIntervalStartedAt = activeIntervalStartedAt
            session.updatedAt = updatedAt
            session.lifecycleStateRaw = lifecycleStateRaw
            session.lastResumedAt = lastResumedAt
            session.dismissedRecoveryPromptAt = dismissedRecoveryPromptAt
            session.endedAt = endedAt
        }
    }
}
