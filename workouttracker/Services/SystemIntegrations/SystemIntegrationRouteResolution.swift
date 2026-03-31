import Foundation

enum SystemIntegrationFallbackReason: Equatable {
    case invalidURL
    case targetSessionMissing
    case targetSessionNotLaunchable
    case targetRoutineMissing
    case targetExerciseMissing
    case noActiveSession
}

enum SystemIntegrationRouteResolution: Equatable {
    case open(AppRoute)
    case fallback(AppRoute, reason: SystemIntegrationFallbackReason)
    case ignore(reason: SystemIntegrationFallbackReason)

    var route: AppRoute? {
        switch self {
        case .open(let route), .fallback(let route, _):
            return route
        case .ignore:
            return nil
        }
    }
}
