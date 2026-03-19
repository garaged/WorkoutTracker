import Foundation

enum ExerciseVolumeTrendDirection: String, Codable, Hashable {
    case up
    case flat
    case down
    case insufficientData
}

struct ExerciseWeeklyVolumeBucket: Identifiable, Hashable {
    var id: Date { weekStart }

    let weekStart: Date
    let sets: Int
    let reps: Int
    let load: Double?
}

struct ExerciseVolumeTrendSummary: Hashable {
    let exerciseID: UUID
    let exerciseName: String
    let weeklyBuckets: [ExerciseWeeklyVolumeBucket]
    let totalSets: Int
    let totalReps: Int
    let totalLoad: Double?
    let trendDirection: ExerciseVolumeTrendDirection
    let dataAvailability: ProgressDataAvailability
}
