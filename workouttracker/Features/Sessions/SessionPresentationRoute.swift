import Foundation

struct SessionPresentationRoute: Identifiable, Hashable {
    let id: UUID
    let session: WorkoutSession
    let initialResumeTarget: SessionResumeTarget?
    let launchRoute: AppRoute?

    init(
        id: UUID = UUID(),
        session: WorkoutSession,
        initialResumeTarget: SessionResumeTarget?,
        launchRoute: AppRoute? = nil
    ) {
        self.id = id
        self.session = session
        self.initialResumeTarget = initialResumeTarget
        self.launchRoute = launchRoute
    }

    static func == (lhs: SessionPresentationRoute, rhs: SessionPresentationRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
