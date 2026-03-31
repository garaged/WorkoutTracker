import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct ActiveWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        enum RestMode: String, Codable, Hashable {
            case inactive
            case running
            case overdue
        }

        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let stateGeneratedAt: Date
        let sessionStartDate: Date
        let restMode: RestMode
        let restReferenceDate: Date?
        let openURLString: String?
    }

    let sessionID: UUID
    let sessionTitle: String
}
#endif
