import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Exercise.name, order: .forward)])
    private var exercises: [Exercise]

    let onPick: (Exercise?) -> Void
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No exercises",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Create an exercise to add it to routines.")
                    )
                } else {
                    List {
                        ForEach(exercises) { ex in
                            Button {
                                onPick(ex)
                                dismiss()
                            } label: {
                                Text(ex.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Exercise")
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
                    ExerciseQuickCreateScreen { created in
                        onPick(created)
                        showCreate = false
                        dismiss()
                    }
                }
            }
        }
    }
}
