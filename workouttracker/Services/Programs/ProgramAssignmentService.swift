import Foundation
import SwiftData

enum ProgramAssignmentService {
    @discardableResult
    static func activateProgram(
        _ program: TrainingProgram,
        startDate: Date,
        anchorStrategy: ProgramScheduleAnchorStrategy,
        context: ModelContext,
        assignedAt: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ProgramAssignment {
        let activeRawValue = ProgramAssignmentStatus.active.rawValue
        let activeAssignments = try context.fetch(
            FetchDescriptor<ProgramAssignment>(
                predicate: #Predicate { $0.statusRaw == activeRawValue }
            )
        )

        for assignment in activeAssignments where assignment.programId != program.id {
            assignment.pause()
        }

        let descriptor = FetchDescriptor<ProgramAssignment>(
            predicate: #Predicate { $0.programId == program.id },
            sortBy: [SortDescriptor(\.assignedAt, order: .reverse)]
        )

        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let firstDayIndex = program.orderedWeeks.first?.orderedDays.first?.index

        let assignment: ProgramAssignment
        if let existing = try context.fetch(descriptor).first {
            existing.programSlug = program.slug
            existing.programNameSnapshot = program.name
            existing.startDate = normalizedStartDate
            existing.assignedAt = assignedAt
            existing.status = .active
            existing.scheduleAnchorStrategy = anchorStrategy

            if let executionState = existing.executionState {
                reset(executionState, firstDayIndex: firstDayIndex, context: context)
            } else {
                existing.executionState = ProgramExecutionState(
                    currentWeekIndex: 1,
                    currentDayIndex: firstDayIndex
                )
            }

            assignment = existing
        } else {
            let created = ProgramAssignment(
                program: program,
                assignedAt: assignedAt,
                startDate: normalizedStartDate,
                status: .active,
                scheduleAnchorStrategy: anchorStrategy
            )
            context.insert(created)
            assignment = created
        }

        try context.save()
        return assignment
    }

    private static func reset(
        _ executionState: ProgramExecutionState,
        firstDayIndex: Int?,
        context: ModelContext
    ) {
        executionState.currentWeekIndex = 1
        executionState.currentDayIndex = firstDayIndex
        executionState.lastEvaluatedAt = nil

        for completedDay in executionState.completedDays {
            context.delete(completedDay)
        }
        executionState.completedDays.removeAll()

        for missedDay in executionState.missedDays {
            context.delete(missedDay)
        }
        executionState.missedDays.removeAll()

        executionState.repeatedWeekIndexes = []
        executionState.deloadedWeekIndexes = []
    }
}
