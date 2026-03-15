import Foundation

struct CompletedSessionAnalyticsSample: Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let wasCompleted: Bool
    let completedExerciseCount: Int
    let durationSeconds: Int?
    let segmentsPresent: Set<WorkoutExerciseSegment>

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        wasCompleted: Bool,
        completedExerciseCount: Int,
        durationSeconds: Int? = nil,
        segmentsPresent: Set<WorkoutExerciseSegment> = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
        self.completedExerciseCount = completedExerciseCount
        self.durationSeconds = durationSeconds
        self.segmentsPresent = segmentsPresent
    }
}
