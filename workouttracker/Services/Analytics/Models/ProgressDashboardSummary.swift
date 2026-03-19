import Foundation

struct ProgressDashboardSummary: Hashable {
    let featuredExercises: [ExerciseProgressSummary]
    let weeklySummary: WeeklyTrainingSummary?
    let consistency: ConsistencySummary
    let efficiency: SessionEfficiencySummary?
    let dataAvailability: ProgressDataAvailability
    let isEmpty: Bool
    let hasLowData: Bool
}
