import Foundation

struct IntentPreconditionResult<Value> {
    let value: Value?
    let failure: IntentPreconditionFailure?

    var isAllowed: Bool {
        value != nil && failure == nil
    }

    static func allow(_ value: Value) -> Self {
        .init(value: value, failure: nil)
    }

    static func block(_ failure: IntentPreconditionFailure) -> Self {
        .init(value: nil, failure: failure)
    }
}

enum IntentPreconditionFailure: String, Error, Equatable {
    case routineNotFound
    case noResumableSession
    case noFinishableSession
    case noRestCapableContext
}

struct IntentPreconditionEvaluator {
    private let sessionResumePlanner: SessionResumePlanner

    init(sessionResumePlanner: SessionResumePlanner = SessionResumePlanner()) {
        self.sessionResumePlanner = sessionResumePlanner
    }

    func existingRoutine(_ routine: WorkoutRoutine?) -> IntentPreconditionResult<WorkoutRoutine> {
        guard let routine else {
            return .block(.routineNotFound)
        }
        return .allow(routine)
    }

    func resumableSession(
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> IntentPreconditionResult<WorkoutSession> {
        guard let session = sessionResumePlanner.currentActiveSession(from: sessions, activitiesByID: activitiesByID) else {
            return .block(.noResumableSession)
        }
        return .allow(session)
    }

    func finishableSession(
        preferredSessionID: UUID? = nil,
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity]
    ) -> IntentPreconditionResult<WorkoutSession> {
        if let preferredSessionID,
           let preferred = sessions.first(where: { $0.id == preferredSessionID }) {
            guard preferred.status == .inProgress, preferred.endedAt == nil else {
                return .block(.noFinishableSession)
            }
            return .allow(preferred)
        }

        guard let session = sessionResumePlanner.currentActiveSession(from: sessions, activitiesByID: activitiesByID),
              session.status == .inProgress,
              session.endedAt == nil else {
            return .block(.noFinishableSession)
        }

        return .allow(session)
    }

    func restCapableSession(
        from sessions: [WorkoutSession],
        activitiesByID: [UUID: Activity],
        hasConfiguredRestTimer: Bool
    ) -> IntentPreconditionResult<WorkoutSession> {
        guard let session = sessionResumePlanner.currentActiveSession(from: sessions, activitiesByID: activitiesByID),
              session.status == .inProgress,
              session.endedAt == nil else {
            return .block(.noRestCapableContext)
        }

        if hasConfiguredRestTimer {
            return .allow(session)
        }

        guard let targetSet = sessionResumePlanner.targetSet(for: session),
              let restSeconds = targetSet.targetRestSeconds,
              restSeconds > 0 else {
            return .block(.noRestCapableContext)
        }

        return .allow(session)
    }
}
