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
        guard activeIDs.isEmpty else { throw RecordingError.activeSessionConflict(activeIDs) }

        let session = WorkoutSessionFactory.makeSession(
            startedAt: now, linkedActivityId: nil, sourceRoutineId: nil,
            sourceRoutineNameSnapshot: sessionName,
            exercises: [.init(order: 0, exerciseId: UUID(),
                              nameSnapshot: normalizedName(genericExerciseName),
                              notes: nil, trackingStyle: .timeOnly, sets: [])],
            prefillActualsFromTargets: false
        )
        guard let exercise = session.exercises.first else { throw RecordingError.invalidRecord }
        begin(exercise, in: session, at: now)
        context.insert(session)
        do { try save(context) }
        catch { context.rollback(); throw error }
        return session
    }

    func startNext(
        catalogExercise: Exercise?,
        genericExerciseName: String,
        in session: WorkoutSession,
        at now: Date = Date(),
        context: ModelContext
    ) throws -> WorkoutSessionExercise {
        try requireClean(context)
        guard session.modelContext === context, session.isUnfinished,
              !session.exercises.contains(where: { $0.freestyleEndedAt == nil })
        else { throw RecordingError.invalidRecord }

        let next = WorkoutSessionExercise(
            order: (session.exercises.map(\.order).max() ?? -1) + 1,
            exerciseId: catalogExercise?.id ?? UUID(),
            exerciseNameSnapshot: catalogExercise.map(ExerciseLocalizationService.displayName(for:)) ?? normalizedName(genericExerciseName),
            trackingStyle: .timeOnly,
            session: session
        )
        begin(next, in: session, at: now)
        let committedExercises = session.exercises
        context.insert(next)
        session.exercises.append(next)
        do { try save(context) }
        catch {
            session.exercises = committedExercises
            context.rollback()
            throw error
        }
        return next
    }

    func finish(
        _ exercise: WorkoutSessionExercise,
        in session: WorkoutSession,
        at now: Date = Date(),
        context: ModelContext
    ) throws {
        try requireClean(context)
        guard session.modelContext === context, exercise.modelContext === context,
              exercise.session?.id == session.id, session.isUnfinished
        else { throw RecordingError.invalidRecord }
        guard exercise.freestyleEndedAt == nil else { return }
        guard exercise.freestyleStartedAt != nil,
              exercise.freestyleStartedSessionElapsedSeconds != nil
        else { throw RecordingError.invalidRecord }

        let previousDuration = exercise.actualDurationSeconds
        exercise.actualDurationSeconds = Self.elapsedSeconds(for: exercise, in: session, at: now)
        exercise.freestyleEndedAt = now
        do { try save(context) }
        catch {
            exercise.actualDurationSeconds = previousDuration
            exercise.freestyleEndedAt = nil
            context.rollback()
            throw error
        }
    }

    static func elapsedSeconds(
        for exercise: WorkoutSessionExercise,
        in session: WorkoutSession,
        at now: Date = Date()
    ) -> Int {
        if let completed = exercise.actualDurationSeconds, exercise.freestyleEndedAt != nil {
            return max(0, completed)
        }
        guard let baseline = exercise.freestyleStartedSessionElapsedSeconds else { return 0 }
        return max(0, session.elapsedSeconds(at: now) - baseline)
    }

    private func begin(_ exercise: WorkoutSessionExercise, in session: WorkoutSession, at now: Date) {
        exercise.freestyleStartedAt = now
        exercise.freestyleStartedSessionElapsedSeconds = session.elapsedSeconds(at: now)
        exercise.freestyleEndedAt = nil
        exercise.actualDurationSeconds = nil
    }

    private func normalizedName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed exercise" : trimmed
    }

    private func requireClean(_ context: ModelContext) throws {
        guard !context.hasChanges else { throw RecordingError.pendingChanges }
    }
}
