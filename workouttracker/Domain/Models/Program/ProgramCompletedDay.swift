import Foundation
import SwiftData

@Model
final class ProgramCompletedDay {
    @Attribute(.unique) var id: UUID

    var programId: UUID
    var weekIndex: Int
    var dayIndex: Int
    var completedAt: Date
    var completionSourceRaw: String
    var sourceRoutineId: UUID?
    var sourceRoutineNameSnapshot: String?
    var workoutSessionId: UUID?

    var executionState: ProgramExecutionState?

    init(
        id: UUID = UUID(),
        programId: UUID,
        weekIndex: Int,
        dayIndex: Int,
        completedAt: Date = Date(),
        completionSource: ProgramCompletedDaySource = .manual,
        sourceRoutineId: UUID? = nil,
        sourceRoutineNameSnapshot: String? = nil,
        workoutSessionId: UUID? = nil
    ) {
        self.id = id
        self.programId = programId
        self.weekIndex = weekIndex
        self.dayIndex = dayIndex
        self.completedAt = completedAt
        self.completionSourceRaw = completionSource.rawValue
        self.sourceRoutineId = sourceRoutineId
        self.sourceRoutineNameSnapshot = sourceRoutineNameSnapshot
        self.workoutSessionId = workoutSessionId
    }

    var completionSource: ProgramCompletedDaySource {
        get { ProgramCompletedDaySource(rawValue: completionSourceRaw) ?? .manual }
        set { completionSourceRaw = newValue.rawValue }
    }
}
