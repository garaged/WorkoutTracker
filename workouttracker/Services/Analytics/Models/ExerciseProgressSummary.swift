import Foundation

struct ExerciseProgressSummary: Hashable {
    struct MetricSnapshot: Hashable {
        let value: Double
        let achievedAt: Date
        let sessionID: UUID
    }

    struct IntMetricSnapshot: Hashable {
        let value: Int
        let achievedAt: Date
        let sessionID: UUID
        let contextWeight: Double?
    }

    struct TopSetSnapshot: Hashable {
        let performedAt: Date
        let sessionID: UUID
        let weight: Double?
        let reps: Int?
        let estimatedOneRepMax: Double?
    }

    let exerciseID: UUID
    let exerciseName: String
    let bestWeight: MetricSnapshot?
    let bestReps: IntMetricSnapshot?
    let bestSetVolume: MetricSnapshot?
    let bestSessionVolume: MetricSnapshot?
    let bestEstimatedOneRepMax: MetricSnapshot?
    let latestTopSet: TopSetSnapshot?
    let latestPerformedAt: Date?
    let personalRecords: [PersonalRecordSummary]
    let dataAvailability: ProgressDataAvailability
}
