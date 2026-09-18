import Foundation
import SwiftData

@MainActor
struct FreestyleWorkoutRecorder {
    enum RecordingError: Error, Equatable {
        case pendingChanges
        case activeSessionConflict([UUID])
        case invalidRecord
    }

    var save: (ModelContext) throws -> Void = { try $0.save() }

    func start(
        sessionName: String,
        genericExerciseName: String,
        at now: Date = Date(),
        context: ModelContext
    ) throws -> WorkoutSession {
        try requireClean(context)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let activeIDs = sessions.filter(\.isUnfinished).map(\.id).sorted { $0.uuidString < $1.uuidString }
        guard activeIDs.isEmpty else {
            throw RecordingError.activeSessionConflict(activeIDs)
        }

        let exerciseName = genericExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = WorkoutSessionFactory.makeSession(
            startedAt: now,
            linkedActivityId: nil,
            sourceRoutineId: nil,
            sourceRoutineNameSnapshot: sessionName,
            exercises: [
                .init(
                    order: 0,
                    exerciseId: UUID(),
                    nameSnapshot: exerciseName.isEmpty ? "Unnamed exercise" : exerciseName,
                    notes: nil,
                    trackingStyle: .timeOnly,
                    sets: []
                )
            ],
            prefillActualsFromTargets: false
        )

        context.insert(session)
        do {
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        return session
    }

    func finish(
        _ exercise: WorkoutSessionExercise,
        in session: WorkoutSession,
        at now: Date = Date(),
        context: ModelContext
    ) throws {
        try requireClean(context)
        guard session.modelContext === context,
              exercise.modelContext === context,
              exercise.session?.id == session.id,
              session.isUnfinished,
              exercise.actualDurationSeconds == nil
        else {
            throw RecordingError.invalidRecord
        }

        exercise.actualDurationSeconds = session.elapsedSeconds(at: now)
        do {
            try save(context)
        } catch {
            exercise.actualDurationSeconds = nil
            context.rollback()
            throw error
        }
    }

    private func requireClean(_ context: ModelContext) throws {
        guard !context.hasChanges else {
            throw RecordingError.pendingChanges
        }
    }
}
