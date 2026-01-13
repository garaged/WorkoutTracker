import SwiftUI
import SwiftData

struct RoutinePickerField: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var routineId: UUID?
    @State private var showPicker = false

    @State private var routineName: String = "None"

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Text("Routine")
                Spacer()
                Text(routineName)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .onAppear { refreshName() }
        .onChange(of: routineId) { _, _ in refreshName() }
        .sheet(isPresented: $showPicker) {
            RoutinePickerSheet(
                selectedRoutineId: routineId,
                onPick: { picked in
                    routineId = picked?.id
                    routineName = picked?.name ?? "None"
                    showPicker = false
                }
            )
        }
    }

    private func refreshName() {
        guard let id = routineId else {
            routineName = "None"
            return
        }

        do {
            let desc = FetchDescriptor<WorkoutRoutine>(
                predicate: #Predicate { r in r.id == id }
            )
            routineName = try modelContext.fetch(desc).first?.name ?? "None"
        } catch {
            routineName = "None"
        }
    }
}
