import Foundation

// File: workouttracker/Services/Workouts/RoutineLinkPlanner.swift
//
// Why this file lives here:
// Linked routine validation and execution ordering are workout-domain rules.
// Keeping them out of the views makes the authoring UI lighter and gives the
// session flow one place to ask for normalized warm-up -> main -> cool-down data.

enum RoutineLinkPlanner {
    enum ValidationResult: Equatable {
        case valid
        case invalid(String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var message: String? {
            guard case .invalid(let message) = self else { return nil }
            return message
        }
    }

    static func validate(mainRoutine: WorkoutRoutine) -> ValidationResult {
        let mainID = mainRoutine.id

        if mainRoutine.warmUpRoutine?.id == mainID {
            return .invalid("A routine cannot link itself as its warm-up.")
        }

        if mainRoutine.coolDownRoutine?.id == mainID {
            return .invalid("A routine cannot link itself as its cool-down.")
        }

        if let warmUp = mainRoutine.warmUpRoutine,
           warmUp.warmUpRoutine?.id == mainID || warmUp.coolDownRoutine?.id == mainID {
            return .invalid("This warm-up routine creates a direct cycle back to the main routine.")
        }

        if let coolDown = mainRoutine.coolDownRoutine,
           coolDown.warmUpRoutine?.id == mainID || coolDown.coolDownRoutine?.id == mainID {
            return .invalid("This cool-down routine creates a direct cycle back to the main routine.")
        }

        return .valid
    }

    static func buildExecutionSegments(for mainRoutine: WorkoutRoutine) -> [RoutineExecutionSegment] {
        var out: [RoutineExecutionSegment] = []
        out.reserveCapacity(3)

        if let warmUp = mainRoutine.warmUpRoutine,
           warmUp.id != mainRoutine.id,
           !warmUp.items.isEmpty {
            out.append(makeExecutionSegment(from: warmUp, kind: .warmUp))
        }

        out.append(makeExecutionSegment(from: mainRoutine, kind: .main))

        if let coolDown = mainRoutine.coolDownRoutine,
           coolDown.id != mainRoutine.id,
           !coolDown.items.isEmpty {
            out.append(makeExecutionSegment(from: coolDown, kind: .coolDown))
        }

        return out
    }

    private static func makeExecutionSegment(
        from routine: WorkoutRoutine,
        kind: SessionSegmentKind
    ) -> RoutineExecutionSegment {
        let items = routine.items.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        return RoutineExecutionSegment(
            kind: kind,
            routineID: routine.id,
            routineName: routine.name,
            exerciseItems: items
        )
    }
}
