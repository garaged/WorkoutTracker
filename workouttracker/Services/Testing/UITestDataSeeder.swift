import Foundation
import SwiftData

@MainActor
enum UITestDataSeeder {

    // Keep IDs stable so UI tests can target specific rows.
    static let activityTitle = "UITest Workout"

    static let sessionId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    static let exerciseId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    static let set0Id = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    static let set1Id = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

    /// Wipes existing data (ONLY for -uiTesting) and inserts 1 workout activity + 1 session + 1 exercise + 2 sets.
    /// Returns the seeded session so the caller can navigate to it.
    static func resetAndSeed(day: Date, context: ModelContext) throws -> WorkoutSession {
        try purgeAll(context: context)

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let startAt = cal.date(byAdding: .hour, value: 9, to: dayStart)!
        let endAt = cal.date(byAdding: .minute, value: 60, to: startAt)!

        // Activity
        let a = Activity(
            title: activityTitle,
            startAt: startAt,
            endAt: endAt,
            laneHint: 0,
            kind: .workout
        )
        a.dayKey = day.dayKey()
        context.insert(a)

        // Session
        let s = WorkoutSession(
            id: sessionId,
            startedAt: startAt,
            sourceRoutineId: nil,
            sourceRoutineNameSnapshot: "UITest Routine",
            linkedActivityId: a.id
        )

        // Exercise
        let ex = WorkoutSessionExercise(
            id: exerciseId,
            order: 0,
            exerciseId: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!, // "definition id" placeholder
            exerciseNameSnapshot: "Bench Press",
            notes: nil,
            session: s
        )

        // Sets
        let set0 = WorkoutSetLog(
            id: set0Id,
            order: 0,
            origin: .planned,
            reps: 10,
            weight: 100,
            weightUnit: .kg,
            completed: false,
            targetReps: 10,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRestSeconds: 90,
            sessionExercise: ex
        )

        let set1 = WorkoutSetLog(
            id: set1Id,
            order: 1,
            origin: .planned,
            reps: 10,
            weight: 100,
            weightUnit: .kg,
            completed: false,
            targetReps: 10,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRestSeconds: 90,
            sessionExercise: ex
        )

        ex.setLogs = [set0, set1]
        s.exercises = [ex]

        // Insert everything (explicit is safest with SwiftData graphs)
        context.insert(s)
        context.insert(ex)
        context.insert(set0)
        context.insert(set1)

        // Link activity -> session
        a.workoutSessionId = s.id

        try context.save()
        return s
    }

    private static func purgeAll(context: ModelContext) throws {
        // Delete sessions first (cascade clears exercises/sets).
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        for s in sessions { context.delete(s) }

        let activities = try context.fetch(FetchDescriptor<Activity>())
        for a in activities { context.delete(a) }

        try context.save()
    }
}
