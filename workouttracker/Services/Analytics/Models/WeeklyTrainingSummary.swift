import Foundation

struct WeeklyTrainingSummary: Identifiable, Hashable {
    var id: Date { weekStart }

    let weekStart: Date
    let workoutsCompleted: Int
    let totalSets: Int
    let totalReps: Int
    let totalLoad: Double?
    let distinctExerciseCount: Int
    let totalDurationSeconds: Int?
    let dataAvailability: ProgressDataAvailability
}
