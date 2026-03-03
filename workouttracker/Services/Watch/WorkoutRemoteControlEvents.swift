import Foundation

extension Notification.Name {
    static let workoutWatchSelectedSet = Notification.Name("workoutWatchSelectedSet")
    static let workoutWatchSetCompletionChanged = Notification.Name("workoutWatchSetCompletionChanged")
}

struct WorkoutWatchSelectedSetEvent: Sendable {
    let sessionID: UUID
    let exerciseID: UUID?
    let setID: UUID?
}

struct WorkoutWatchSetCompletionChangedEvent: Sendable {
    let sessionID: UUID
    let setID: UUID
    let isCompleted: Bool
}
