import SwiftUI
import SwiftData

struct RoutinePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    let selectedRoutineId: UUID?
    let onPick: (WorkoutRoutine?) -> Void

    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "No routines yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a routine to attach workouts to this template.")
                    )
                } else {
                    List {
                        Section {
                            Button {
                                onPick(nil)   // ✅ None / clear selection
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
                            ForEach(routines) { r in
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
            .navigationTitle("Pick Routine")
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
                        // Save + select immediately
                        onPick(created)
                        showCreate = false
                    }
                }
            }
        }
    }
}
