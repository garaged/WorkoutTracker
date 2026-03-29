import XCTest
@testable import workouttracker

final class SessionResumePlannerTests: XCTestCase {

    func test_currentActiveSession_prefersTodayLinkedActivityOverPreviousDaySession() {
        let calendar = Calendar.current
        let planner = SessionResumePlanner(calendar: calendar)
        let now = Date()

        let todaySession = WorkoutSession(startedAt: now.addingTimeInterval(-1800))
        todaySession.status = .inProgress
        todaySession.endedAt = nil

        let previousDaySession = WorkoutSession(startedAt: now.addingTimeInterval(-3600))
        previousDaySession.status = .inProgress
        previousDaySession.endedAt = nil

        let todayActivity = Activity(
            title: "Today",
            startAt: now.addingTimeInterval(-1200),
            endAt: now.addingTimeInterval(2400),
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: nil
        )

        let previousDayActivity = Activity(
            title: "Yesterday",
            startAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now.addingTimeInterval(-86_400),
            endAt: nil,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: nil
        )

        todaySession.linkedActivityId = todayActivity.id
        previousDaySession.linkedActivityId = previousDayActivity.id

        let selected = planner.currentActiveSession(
            from: [previousDaySession, todaySession],
            activitiesByID: [
                todayActivity.id: todayActivity,
                previousDayActivity.id: previousDayActivity
            ]
        )

        XCTAssertEqual(selected?.id, todaySession.id)
    }

    func test_currentResumeTarget_picksFirstIncompleteSetAcrossOrderedExercises() {
        let planner = SessionResumePlanner()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil

        let firstExercise = WorkoutSessionExercise(order: 1, exerciseId: UUID(), exerciseNameSnapshot: "Bench Press")
        let completed = WorkoutSetLog(
            order: 0,
            origin: .added,
            reps: 10,
            weight: 100,
            weightUnit: .kg,
            rpe: nil,
            completed: true,
            completedAt: Date(),
            targetReps: 10,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: 120,
            sessionExercise: nil
        )
        firstExercise.setLogs = [completed]

        let secondExercise = WorkoutSessionExercise(order: 0, exerciseId: UUID(), exerciseNameSnapshot: "Squat")
        let nextSet = WorkoutSetLog(
            order: 0,
            origin: .added,
            reps: 5,
            weight: 140,
            weightUnit: .kg,
            rpe: nil,
            completed: false,
            completedAt: nil,
            targetReps: 5,
            targetWeight: 140,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: 180,
            sessionExercise: nil
        )
        secondExercise.setLogs = [nextSet]

        session.exercises = [firstExercise, secondExercise]

        let target = planner.currentResumeTarget(for: session)

        XCTAssertEqual(target?.sessionID, session.id)
        XCTAssertEqual(target?.exerciseID, secondExercise.id)
        XCTAssertEqual(target?.setID, nextSet.id)
        XCTAssertEqual(target?.reason, .nextIncompleteSet)
    }

    func test_currentResumeTarget_returnsNoSetsReasonForEmptySession() {
        let planner = SessionResumePlanner()
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil
        session.exercises = []

        let target = planner.currentResumeTarget(for: session)

        XCTAssertEqual(target?.sessionID, session.id)
        XCTAssertNil(target?.exerciseID)
        XCTAssertNil(target?.setID)
        XCTAssertEqual(target?.reason, .noSets)
    }

    func test_openRoute_returnsCanonicalSessionRoot() {
        let planner = SessionResumePlanner()
        let session = WorkoutSession(startedAt: Date())

        XCTAssertEqual(planner.openRoute(for: session), .session(sessionID: session.id))
    }
}
