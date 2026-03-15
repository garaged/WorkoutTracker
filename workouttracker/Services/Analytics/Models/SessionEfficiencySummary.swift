import Foundation

struct SessionEfficiencySummary: Hashable {
    struct ExerciseRestOverrunSummary: Identifiable, Hashable {
        var id: UUID { exerciseID }

        let exerciseID: UUID
        let exerciseName: String
        let averageOverrunSeconds: Double
        let sampleCount: Int
    }

    let averageSessionDurationSeconds: Double?
    let averagePlannedRestSeconds: Double?
    let averageActualRestSeconds: Double?
    let averageRestOverrunSeconds: Double?
    let highestAverageRestOverrunExercises: [ExerciseRestOverrunSummary]
    let availability: ProgressDataAvailability
}
