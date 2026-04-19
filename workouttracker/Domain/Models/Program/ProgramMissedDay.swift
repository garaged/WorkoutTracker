import Foundation
import SwiftData

@Model
final class ProgramMissedDay {
    @Attribute(.unique) var id: UUID

    var programId: UUID
    var weekIndex: Int
    var dayIndex: Int
    var markedAt: Date
    var reasonRaw: String

    var executionState: ProgramExecutionState?

    init(
        id: UUID = UUID(),
        programId: UUID,
        weekIndex: Int,
        dayIndex: Int,
        markedAt: Date = Date(),
        reason: ProgramMissedDayReason = .unknown
    ) {
        self.id = id
        self.programId = programId
        self.weekIndex = weekIndex
        self.dayIndex = dayIndex
        self.markedAt = markedAt
        self.reasonRaw = reason.rawValue
    }

    var reason: ProgramMissedDayReason {
        get { ProgramMissedDayReason(rawValue: reasonRaw) ?? .unknown }
        set { reasonRaw = newValue.rawValue }
    }
}
