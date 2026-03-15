import Foundation

struct ExerciseProgressDetailSummary: Hashable {
    struct EstimatedOneRepMaxSummary: Hashable {
        let value: Double
        let achievedAt: Date
        let sessionID: UUID
    }

    let exerciseID: UUID
    let exerciseName: String
    let personalRecords: [PersonalRecordSummary]
    let weeklyVolumeTrend: ExerciseVolumeTrendSummary
    let recentPerformanceSamples: [ExercisePerformanceSample]
    let estimatedOneRepMax: EstimatedOneRepMaxSummary?
    let latestTopSet: ExerciseProgressSummary.TopSetSnapshot?
    let dataAvailability: ProgressDataAvailability
    let hasLowData: Bool
}
