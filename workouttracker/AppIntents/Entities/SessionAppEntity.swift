import Foundation
import AppIntents

struct SessionAppEntity: AppEntity, Identifiable, Equatable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Session")
    static let defaultQuery = SessionEntityQuery()

    let id: UUID
    let title: String
    let detail: String?

    init(id: UUID, title: String, detail: String?) {
        self.id = id
        self.title = title
        self.detail = detail
    }

    init(session: WorkoutSession, resumePlanner: SessionResumePlanner = SessionResumePlanner()) {
        let title = session.sourceRoutineNameSnapshot ?? "Workout Session"
        let target = resumePlanner.currentResumeTarget(for: session)

        let detail: String?
        if let exerciseID = target?.exerciseID,
           let exercise = session.exercises.first(where: { $0.id == exerciseID }) {
            detail = exercise.exerciseNameSnapshot
        } else {
            detail = nil
        }

        self.init(id: session.id, title: title, detail: detail)
    }

    var displayRepresentation: DisplayRepresentation {
        let titleResource: LocalizedStringResource = "\(title)"

        if let detail, !detail.isEmpty {
            let subtitleResource: LocalizedStringResource = "\(detail)"
            return DisplayRepresentation(title: titleResource, subtitle: subtitleResource)
        }

        return DisplayRepresentation(title: titleResource)
    }
}
