import Foundation

enum WidgetDeepLinks {
    static let homeURL = URL(string: "workouttracker://home")!

    #if os(watchOS)
    static let watchShortcutsURL = URL(string: "workouttrackerwatch://shortcuts")!
    static let watchNowPlayingURL = URL(string: "workouttrackerwatch://now-playing")!
    #endif

    static func preferredURL(for session: WorkoutWidgetSnapshot.ActiveSession?) -> URL {
        #if os(watchOS)
        return session == nil ? watchShortcutsURL : watchNowPlayingURL
        #else
        return preferredLaunchURL(for: session) ?? homeURL
        #endif
    }

    static func preferredLaunchURL(for session: WorkoutWidgetSnapshot.ActiveSession?) -> URL? {
        guard let session else { return nil }

        if session.restState != .inactive,
           let url = validatedURL(from: session.restRouteURL) {
            return url
        }

        if session.isResumable,
           let url = validatedURL(from: session.resumeRouteURL) {
            return url
        }

        if let url = validatedURL(from: session.openRouteURL) {
            return url
        }

        return nil
    }

    static func streakURL() -> URL {
        #if os(watchOS)
        return watchShortcutsURL
        #else
        return homeURL
        #endif
    }

    private static func validatedURL(from rawValue: String?) -> URL? {
        guard let rawValue,
              let url = URL(string: rawValue),
              url.scheme == homeURL.scheme else {
            return nil
        }

        return url
    }
}
