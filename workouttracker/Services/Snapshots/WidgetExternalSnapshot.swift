import Foundation

struct WidgetExternalSnapshot: Codable, Equatable {
    struct ActiveSession: Codable, Equatable {
        enum RestState: String, Codable, Equatable {
            case inactive
            case running
            case overdue
        }

        let sessionID: UUID
        let title: String?
        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let elapsedSeconds: Int
        let restState: RestState
        let restSeconds: Int?
        let isResumable: Bool
        let isFinishable: Bool
        let openRouteURL: String?
        let resumeRouteURL: String?
        let restRouteURL: String?
    }

    struct Streak: Codable, Equatable {
        let currentStreakDays: Int
        let longestStreakDays: Int
        let workoutsThisWeek: Int
    }

    let generatedAt: Date
    let activeSession: ActiveSession?
    let streak: Streak
    let schemaVersion: Int

    static let currentSchemaVersion = 1
}
