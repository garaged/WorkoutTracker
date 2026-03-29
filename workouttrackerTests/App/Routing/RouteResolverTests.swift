import XCTest
@testable import workouttracker

final class RouteResolverTests: XCTestCase {
    private let resolver = RouteResolver(calendar: Calendar(identifier: .gregorian))

    func test_payload_parsesSessionExercisePath() throws {
        let url = try XCTUnwrap(URL(string: "workouttracker://session/11111111-1111-1111-1111-111111111111/exercise/22222222-2222-2222-2222-222222222222"))
        let payload = try XCTUnwrap(resolver.payload(for: url))

        guard case .session(let sessionPayload) = payload else {
            return XCTFail("Expected a session payload.")
        }

        XCTAssertEqual(sessionPayload.sessionID.uuidString.lowercased(), "11111111-1111-1111-1111-111111111111")

        guard case .exercise(let exerciseID) = sessionPayload.target else {
            return XCTFail("Expected an exercise launch target.")
        }

        XCTAssertEqual(exerciseID.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
    }

    func test_payload_parsesRestQueryVariant() throws {
        let url = try XCTUnwrap(URL(string: "workouttracker://session?id=11111111-1111-1111-1111-111111111111&rest=true"))
        let payload = try XCTUnwrap(resolver.payload(for: url))

        guard case .session(let sessionPayload) = payload else {
            return XCTFail("Expected a session payload.")
        }

        guard case .rest = sessionPayload.target else {
            return XCTFail("Expected a rest launch target.")
        }
    }

    func test_payload_parsesCalendarDay() throws {
        let url = try XCTUnwrap(URL(string: "workouttracker://calendar?date=2026-03-28"))
        let payload = try XCTUnwrap(resolver.payload(for: url))

        guard case .calendarDay(let dayPayload) = payload else {
            return XCTFail("Expected a calendar-day payload.")
        }

        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: dayPayload.date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 28)
    }

    func test_route_forMissingExerciseFallsBackToSessionRoot() {
        let session = WorkoutSession(startedAt: Date())
        session.status = .inProgress
        session.endedAt = nil

        let payload = RoutePayload.session(
            .init(sessionID: session.id, target: .exercise(UUID()))
        )

        let route = resolver.route(for: payload, sessions: [session], routines: [])
        XCTAssertEqual(route, .session(sessionID: session.id))
    }

    func test_route_forFinishedSessionFallsBackToHome() {
        let session = WorkoutSession(startedAt: Date())
        session.status = .completed
        session.endedAt = Date()

        let payload = RoutePayload.session(
            .init(sessionID: session.id, target: .session)
        )

        let route = resolver.route(for: payload, sessions: [session], routines: [])
        XCTAssertEqual(route, .home)
    }

    func test_route_forExistingRoutineResolvesExactRoutine() {
        let routine = WorkoutRoutine(name: "Route Resolver Routine")
        let payload = RoutePayload.routine(.init(routineID: routine.id))

        let route = resolver.route(for: payload, sessions: [], routines: [routine])
        XCTAssertEqual(route, .routine(routineID: routine.id))
    }

    func test_route_forMissingRoutineFallsBackToHome() {
        let payload = RoutePayload.routine(.init(routineID: UUID()))

        let route = resolver.route(for: payload, sessions: [], routines: [])
        XCTAssertEqual(route, .home)
    }
}
