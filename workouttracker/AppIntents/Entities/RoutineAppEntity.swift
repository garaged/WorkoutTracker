import Foundation
import AppIntents

struct RoutineAppEntity: AppEntity, Identifiable, Equatable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Routine")
    static let defaultQuery = RoutineEntityQuery()

    let id: UUID
    let name: String
    let notesPreview: String?

    init(id: UUID, name: String, notesPreview: String?) {
        self.id = id
        self.name = name
        self.notesPreview = notesPreview
    }

    init(routine: WorkoutRoutine) {
        self.init(
            id: routine.id,
            name: routine.name,
            notesPreview: routine.notes
        )
    }

    var displayRepresentation: DisplayRepresentation {
        let title: LocalizedStringResource = "\(name)"

        if let notesPreview, !notesPreview.isEmpty {
            let subtitle: LocalizedStringResource = "\(notesPreview)"
            return DisplayRepresentation(title: title, subtitle: subtitle)
        }

        return DisplayRepresentation(title: title)
    }
}
