import Foundation

enum IntentLaunchBridge {
    private static let pendingURLKey = "workouttracker.intent.pendingURL"
    private static let calendarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func url(for route: AppRoute) -> URL? {
        switch route {
        case .home:
            return URL(string: "workouttracker://home")

        case .session(let sessionID):
            return URL(string: "workouttracker://session/\(sessionID.uuidString)")

        case .sessionExercise(let sessionID, let exerciseID):
            return URL(string: "workouttracker://session/\(sessionID.uuidString)/exercise/\(exerciseID.uuidString)")

        case .sessionRest(let sessionID):
            return URL(string: "workouttracker://session/\(sessionID.uuidString)/rest")

        case .routine(let routineID):
            return URL(string: "workouttracker://routine/\(routineID.uuidString)")

        case .calendarDay(let date):
            let day = calendarFormatter.string(from: date)
            return URL(string: "workouttracker://calendar/\(day)")
        }
    }

    static func stage(route: AppRoute, defaults: UserDefaults = .standard) {
        guard let url = url(for: route) else { return }
        defaults.set(url.absoluteString, forKey: pendingURLKey)
    }

    static func peekPendingURL(defaults: UserDefaults = .standard) -> URL? {
        guard let raw = defaults.string(forKey: pendingURLKey) else { return nil }
        return URL(string: raw)
    }

    static func clearPendingURL(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingURLKey)
    }
}
