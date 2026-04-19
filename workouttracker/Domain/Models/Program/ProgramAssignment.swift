import Foundation
import SwiftData

@Model
final class ProgramAssignment {
    @Attribute(.unique) var id: UUID

    var programId: UUID
    var programSlug: String
    var programNameSnapshot: String

    var assignedAt: Date
    var startDate: Date

    var statusRaw: String
    var scheduleAnchorStrategyRaw: String

    @Relationship(deleteRule: .cascade, inverse: \ProgramExecutionState.assignment)
    var executionState: ProgramExecutionState?

    init(
        id: UUID = UUID(),
        program: TrainingProgram,
        assignedAt: Date = Date(),
        startDate: Date,
        status: ProgramAssignmentStatus = .active,
        scheduleAnchorStrategy: ProgramScheduleAnchorStrategy = .calendarAligned,
        executionState: ProgramExecutionState? = nil
    ) {
        self.id = id
        self.programId = program.id
        self.programSlug = program.slug
        self.programNameSnapshot = program.name
        self.assignedAt = assignedAt
        self.startDate = startDate
        self.statusRaw = status.rawValue
        self.scheduleAnchorStrategyRaw = scheduleAnchorStrategy.rawValue
        self.executionState = executionState ?? ProgramExecutionState(
            currentWeekIndex: 1,
            currentDayIndex: program.orderedWeeks.first?.orderedDays.first?.index
        )
    }

    var status: ProgramAssignmentStatus {
        get { ProgramAssignmentStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var scheduleAnchorStrategy: ProgramScheduleAnchorStrategy {
        get { ProgramScheduleAnchorStrategy(rawValue: scheduleAnchorStrategyRaw) ?? .calendarAligned }
        set { scheduleAnchorStrategyRaw = newValue.rawValue }
    }

    var isActive: Bool {
        status == .active
    }

    func pause() {
        status = .paused
    }

    func resume() {
        status = .active
    }

    func complete() {
        status = .completed
    }
}
