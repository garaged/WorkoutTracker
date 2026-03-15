import Foundation

struct ExercisePerformanceSample: Identifiable, Hashable {
    let id: UUID
    let exerciseID: UUID
    let exerciseName: String
    let sessionID: UUID
    let sessionStartedAt: Date
    let performedAt: Date
    let segment: WorkoutExerciseSegment
    let weight: Double?
    let reps: Int?
    let isCompleted: Bool
    let plannedRestSeconds: Int?
    let actualRestSeconds: Int?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseName: String,
        sessionID: UUID,
        sessionStartedAt: Date,
        performedAt: Date,
        segment: WorkoutExerciseSegment = .main,
        weight: Double? = nil,
        reps: Int? = nil,
        isCompleted: Bool = true,
        plannedRestSeconds: Int? = nil,
        actualRestSeconds: Int? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sessionID = sessionID
        self.sessionStartedAt = sessionStartedAt
        self.performedAt = performedAt
        self.segment = segment
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.plannedRestSeconds = plannedRestSeconds
        self.actualRestSeconds = actualRestSeconds
    }
}
