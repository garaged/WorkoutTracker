import Foundation
import SwiftData

enum ProgramExecutionUpdateService {
    static func recordCompletedSession(
        _ session: WorkoutSession,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        guard session.status == .completed,
              let assignmentID = session.programAssignmentId ?? activeAssignmentID(for: session, context: context),
              let assignment = try fetchAssignment(id: assignmentID, context: context),
              let executionState = assignment.executionState,
              let programID = session.sourceProgramId,
              let weekIndex = session.sourceProgramWeekIndex,
              let dayIndex = session.sourceProgramDayIndex else {
            return
        }

        if let existing = executionState.completedDays.first(where: {
            $0.programId == programID && $0.weekIndex == weekIndex && $0.dayIndex == dayIndex
        }) {
            existing.completedAt = session.endedAt ?? now
            existing.completionSource = .workoutSession
            existing.workoutSessionId = session.id
            existing.sourceRoutineId = session.sourceRoutineId
            existing.sourceRoutineNameSnapshot = session.sourceRoutineNameSnapshot
        } else {
            let completedDay = ProgramCompletedDay(
                programId: programID,
                weekIndex: weekIndex,
                dayIndex: dayIndex,
                completedAt: session.endedAt ?? now,
                completionSource: .workoutSession,
                sourceRoutineId: session.sourceRoutineId,
                sourceRoutineNameSnapshot: session.sourceRoutineNameSnapshot,
                workoutSessionId: session.id
            )
            completedDay.executionState = executionState
            executionState.completedDays.append(completedDay)
            context.insert(completedDay)
        }

        executionState.missedDays.removeAll {
            $0.programId == programID && $0.weekIndex == weekIndex && $0.dayIndex == dayIndex
        }

        executionState.lastEvaluatedAt = now
        executionState.currentWeekIndex = max(weekIndex, executionState.currentWeekIndex)
        executionState.currentDayIndex = dayIndex
    }

    private static func activeAssignmentID(
        for session: WorkoutSession,
        context: ModelContext
    ) -> UUID? {
        guard let programID = session.sourceProgramId else { return nil }
        let activeRawValue = ProgramAssignmentStatus.active.rawValue
        let descriptor = FetchDescriptor<ProgramAssignment>(
            predicate: #Predicate { $0.programId == programID && $0.statusRaw == activeRawValue },
            sortBy: [SortDescriptor(\.assignedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first?.id
    }

    private static func fetchAssignment(
        id: UUID,
        context: ModelContext
    ) throws -> ProgramAssignment? {
        let descriptor = FetchDescriptor<ProgramAssignment>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
}
