import Foundation

enum WidgetDeepLinks {
    static let homeURL = URL(string: "workouttracker://home")!

    static func preferredURL(for session: WorkoutWidgetSnapshot.ActiveSession?) -> URL {
        if let raw = session?.resumeRouteURL,
           let url = URL(string: raw) {
            return url
        }

        if let raw = session?.restRouteURL,
           let url = URL(string: raw) {
            return url
        }

        if let raw = session?.openRouteURL,
           let url = URL(string: raw) {
            return url
        }

        return homeURL
    }

    static func streakURL() -> URL {
        homeURL
    }
}
