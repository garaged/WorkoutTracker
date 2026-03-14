import SwiftUI
import SwiftData

struct RoutinePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    let title: String
    let selectedRoutineId: UUID?
    let excludedRoutineIDs: Set<UUID>
    let onPick: (WorkoutRoutine?) -> Void

    @State private var showCreate = false

    init(
        title: String = "Pick Routine",
        selectedRoutineId: UUID?,
        excludedRoutineIDs: Set<UUID> = [],
        onPick: @escaping (WorkoutRoutine?) -> Void
    ) {
        self.title = title
        self.selectedRoutineId = selectedRoutineId
        self.excludedRoutineIDs = excludedRoutineIDs
        self.onPick = onPick
    }

    private var selectableRoutines: [WorkoutRoutine] {
        routines.filter { !excludedRoutineIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if selectableRoutines.isEmpty {
                    ContentUnavailableView(
                        "No routines available",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create another routine to pick it from the list.")
                    )
                } else {
                    List {
                        Section {
                            Button {
                                onPick(nil)
                            } label: {
                                HStack {
                                    Text("None")
                                    Spacer()
                                    if selectedRoutineId == nil {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }

                        Section("Routines") {
                            ForEach(selectableRoutines) { r in
                                Button {
                                    onPick(r)
                                } label: {
                                    HStack {
                                        Text(r.name)
                                        Spacer()
                                        if r.id == selectedRoutineId {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    RoutineQuickCreateScreen { created in
                        onPick(created)
                        showCreate = false
                    }
                }
            }
        }
    }
}
