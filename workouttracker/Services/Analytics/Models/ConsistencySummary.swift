import Foundation

struct ConsistencySummary: Hashable {
    let window: DateInterval
    let activeWeeks: Int
    let totalWeeks: Int
    let averageWorkoutsPerWeek: Double
    let completionRate: Double?
    let dataAvailability: ProgressDataAvailability
}
