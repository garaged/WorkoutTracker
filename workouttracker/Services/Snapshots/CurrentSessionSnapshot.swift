import Foundation

struct CurrentSessionSnapshot: Equatable {
    enum RestState: Equatable {
        case inactive
        case running
        case overdue
    }

    let sessionID: UUID?
    let sessionTitle: String?
    let currentExerciseName: String?
    let currentSetIndex: Int?
    let totalSets: Int?
    let elapsedSeconds: TimeInterval?
    let restState: RestState
    let restSeconds: Int?
    let isResumable: Bool
    let isFinishable: Bool
    let openRoute: AppRoute?
    let resumeRoute: AppRoute?
    let restRoute: AppRoute?

    static let empty = CurrentSessionSnapshot(
        sessionID: nil,
        sessionTitle: nil,
        currentExerciseName: nil,
        currentSetIndex: nil,
        totalSets: nil,
        elapsedSeconds: nil,
        restState: .inactive,
        restSeconds: nil,
        isResumable: false,
        isFinishable: false,
        openRoute: nil,
        resumeRoute: nil,
        restRoute: nil
    )
}
