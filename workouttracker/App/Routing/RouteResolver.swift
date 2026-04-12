import Foundation

struct RouteResolver {
    private let calendar: Calendar
    private let iso8601 = ISO8601DateFormatter()

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func payload(for url: URL) -> RoutePayload? {
        let normalizedSegments = normalizedSegments(for: url)
        guard let first = normalizedSegments.first else {
            return .home
        }

        switch first {
        case "home":
            return .home

        case "session":
            return sessionPayload(from: url, segments: normalizedSegments)

        case "tracked-activity", "trackedactivity", "activity":
            if let id = queryUUID(named: "id", in: url) ?? uuid(at: 1, in: normalizedSegments) {
                return .trackedActivity(.init(sessionID: id))
            }
            return nil

        case "routine":
            if let id = queryUUID(named: "id", in: url) ?? uuid(at: 1, in: normalizedSegments) {
                return .routine(.init(routineID: id))
            }
            return nil

        case "calendar", "day":
            if let date = queryDate(named: "date", in: url) ?? date(at: 1, in: normalizedSegments) {
                return .calendarDay(.init(date: calendar.startOfDay(for: date)))
            }
            return nil

        default:
            return nil
        }
    }

    func route(
        for payload: RoutePayload,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine]
    ) -> AppRoute? {
        switch payload {
        case .home:
            return .home

        case .calendarDay(let payload):
            return .calendarDay(date: calendar.startOfDay(for: payload.date))

        case .routine(let payload):
            guard routines.contains(where: { $0.id == payload.routineID }) else {
                return .home
            }
            return .routine(routineID: payload.routineID)

        case .trackedActivity(let payload):
            guard let session = trackedActivitySessions.first(where: { $0.id == payload.sessionID }) else {
                return .home
            }
            guard isLaunchable(session) else {
                return .home
            }
            return .trackedActivity(sessionID: payload.sessionID)

        case .session(let payload):
            guard let session = sessions.first(where: { $0.id == payload.sessionID }) else {
                return .home
            }

            guard isLaunchable(session) else {
                return .home
            }

            switch payload.target {
            case .session:
                return .session(sessionID: payload.sessionID)
            case .exercise(let exerciseID):
                if session.exercises.contains(where: { $0.id == exerciseID }) {
                    return .sessionExercise(sessionID: payload.sessionID, exerciseID: exerciseID)
                }
                return .session(sessionID: payload.sessionID)
            case .rest:
                return .sessionRest(sessionID: payload.sessionID)
            }
        }
    }

    func route(
        for url: URL,
        sessions: [WorkoutSession],
        trackedActivitySessions: [TrackedActivitySession],
        routines: [WorkoutRoutine]
    ) -> AppRoute? {
        guard let payload = payload(for: url) else { return nil }
        return route(for: payload, sessions: sessions, trackedActivitySessions: trackedActivitySessions, routines: routines)
    }

    private func normalizedSegments(for url: URL) -> [String] {
        let pathSegments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        if let host = url.host, !host.isEmpty {
            return [host.lowercased()] + pathSegments
        }

        return pathSegments.map { $0.lowercased() }
    }

    private func sessionPayload(from url: URL, segments: [String]) -> RoutePayload? {
        let sessionID = queryUUID(named: "id", in: url) ?? uuid(at: 1, in: segments)
        guard let sessionID else { return nil }

        if let exerciseID = queryUUID(named: "exerciseID", in: url) {
            return .session(.init(sessionID: sessionID, target: .exercise(exerciseID)))
        }

        if let rest = queryBool(named: "rest", in: url), rest {
            return .session(.init(sessionID: sessionID, target: .rest))
        }

        if segments.count >= 4, segments[2] == "exercise", let exerciseID = UUID(uuidString: segments[3]) {
            return .session(.init(sessionID: sessionID, target: .exercise(exerciseID)))
        }

        if segments.count >= 3, segments[2] == "rest" {
            return .session(.init(sessionID: sessionID, target: .rest))
        }

        return .session(.init(sessionID: sessionID, target: .session))
    }

    private func queryUUID(named name: String, in url: URL) -> UUID? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?
            .first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?
            .value
            .flatMap(UUID.init(uuidString:))
    }

    private func queryBool(named name: String, in url: URL) -> Bool? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        guard let value = components.queryItems?
            .first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?
            .value?
            .lowercased() else {
            return nil
        }

        switch value {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }

    private func queryDate(named name: String, in url: URL) -> Date? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        guard let raw = components.queryItems?
            .first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?
            .value else {
            return nil
        }

        return date(from: raw)
    }

    private func uuid(at index: Int, in segments: [String]) -> UUID? {
        guard segments.indices.contains(index) else { return nil }
        return UUID(uuidString: segments[index])
    }

    private func date(at index: Int, in segments: [String]) -> Date? {
        guard segments.indices.contains(index) else { return nil }
        return date(from: segments[index])
    }

    private func date(from raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let parsed = iso8601.date(from: trimmed) {
            return parsed
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private func isLaunchable(_ session: WorkoutSession) -> Bool {
        session.status == .inProgress && session.endedAt == nil
    }

    private func isLaunchable(_ session: TrackedActivitySession) -> Bool {
        session.lifecycleState == .inProgress || session.lifecycleState == .paused
    }
}
