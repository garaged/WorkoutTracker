import Foundation

struct SessionPresentationRoute: Identifiable, Hashable {
    let id: UUID
    let session: WorkoutSession
    let initialResumeTarget: SessionResumeTarget?

    init(
        id: UUID = UUID(),
        session: WorkoutSession,
        initialResumeTarget: SessionResumeTarget?
    ) {
        self.id = id
        self.session = session
        self.initialResumeTarget = initialResumeTarget
    }

    static func == (lhs: SessionPresentationRoute, rhs: SessionPresentationRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
