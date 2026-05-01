import XCTest
import SwiftData
@testable import workouttracker

final class WatchRouteLaunchStateMachineTests: XCTestCase {
    func test_armThenConsumeAutoOpen_opensNowPlayingWhenSessionBecomesAvailable() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.consumeAutoOpenIfPossible(hasActiveSession: true)

        XCTAssertEqual(machine.route, .nowPlaying)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }

    func test_consumeAutoOpen_doesNothingWithoutSession() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.consumeAutoOpenIfPossible(hasActiveSession: false)

        XCTAssertEqual(machine.route, .shortcuts)
        XCTAssertTrue(machine.shouldAutoOpenControls)
    }

    func test_showShortcuts_clearsAutoOpenIntent() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()
        machine.openNowPlaying()

        machine.showShortcuts()

        XCTAssertEqual(machine.route, .shortcuts)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }

    func test_openNowPlaying_clearsAutoOpenIntent() {
        var machine = WatchRouteLaunchStateMachine()
        machine.armAutoOpenControls()

        machine.openNowPlaying()

        XCTAssertEqual(machine.route, .nowPlaying)
        XCTAssertFalse(machine.shouldAutoOpenControls)
    }
}

@MainActor
final class WorkoutRemoteControlRouterTests: XCTestCase {
    override func tearDown() {
        SessionRestTimerController.shared.stop()
        super.tearDown()
    }

    func test_markSetComplete_doesNotAdvanceWatchCursor() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let session = WorkoutSession(startedAt: Date())
        let exercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: UUID(),
            exerciseNameSnapshot: "Bench Press",
            session: session
        )
        let first = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: 5,
            weight: 100,
            completed: false,
            targetReps: 5,
            targetWeight: 100,
            targetRestSeconds: 90,
            sessionExercise: exercise
        )
        let second = WorkoutSetLog(
            order: 1,
            origin: .planned,
            reps: 5,
            weight: 105,
            completed: false,
            targetReps: 5,
            targetWeight: 105,
            targetRestSeconds: 90,
            sessionExercise: exercise
        )

        session.exercises.append(exercise)
        exercise.setLogs = [first, second]

        context.insert(session)
        context.insert(exercise)
        context.insert(first)
        context.insert(second)
        try context.save()

        let router = WorkoutRemoteControlRouter.shared
        router.start(modelContainer: store.container)
        router.updateCursor(sessionID: session.id, exerciseID: exercise.id, setID: first.id)

        var selectedSetEvents: [WorkoutWatchSelectedSetEvent] = []
        var completionEvents: [WorkoutWatchSetCompletionChangedEvent] = []

        let selectedObserver = NotificationCenter.default.addObserver(
            forName: .workoutWatchSelectedSet,
            object: nil,
            queue: nil
        ) { note in
            if let event = note.object as? WorkoutWatchSelectedSetEvent {
                selectedSetEvents.append(event)
            }
        }

        let completionObserver = NotificationCenter.default.addObserver(
            forName: .workoutWatchSetCompletionChanged,
            object: nil,
            queue: nil
        ) { note in
            if let event = note.object as? WorkoutWatchSetCompletionChangedEvent {
                completionEvents.append(event)
            }
        }

        defer {
            NotificationCenter.default.removeObserver(selectedObserver)
            NotificationCenter.default.removeObserver(completionObserver)
            router.clearNowPlaying(sessionID: session.id)
        }

        WatchConnectivityService.shared.onCommand?(
            WatchCommand(
                kind: .markSetComplete,
                sessionID: session.id.uuidString,
                setID: first.id.uuidString
            )
        )

        let refreshedFirst = try XCTUnwrap(fetchSet(id: first.id, context: context))
        let refreshedSecond = try XCTUnwrap(fetchSet(id: second.id, context: context))

        XCTAssertTrue(refreshedFirst.completed)
        XCTAssertFalse(refreshedSecond.completed)
        XCTAssertTrue(SessionRestTimerController.shared.hasConfiguredTimer)
        XCTAssertEqual(completionEvents.count, 1)
        XCTAssertEqual(completionEvents.first?.sessionID, session.id)
        XCTAssertEqual(completionEvents.first?.setID, first.id)
        XCTAssertTrue(selectedSetEvents.isEmpty, "Completing a set from watch should not advance the selected set.")
    }

    private func fetchSet(id: UUID, context: ModelContext) -> WorkoutSetLog? {
        let descriptor = FetchDescriptor<WorkoutSetLog>()
        return try? context.fetch(descriptor).first(where: { $0.id == id })
    }
}
