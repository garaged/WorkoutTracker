import SwiftUI
import SwiftData

struct RoutineEditorScreen: View {
    enum Mode {
        case create
        case edit(WorkoutRoutine)
    }

    private let mode: Mode

    // ✅ Default mode fixes “Missing argument for parameter 'mode'”
    init(mode: Mode = .create) {
        self.mode = mode
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Routine Editor",
                systemImage: "list.bullet.rectangle",
                description: Text(modeDescription)
            )
            .navigationTitle(title)
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Routine"
        case .edit:   return "Edit Routine"
        }
    }

    private var modeDescription: String {
        switch mode {
        case .create:
            return "Next: create/edit routine + reorder exercises."
        case .edit(let r):
            return "Editing: \(r.name)"
        }
    }
}
