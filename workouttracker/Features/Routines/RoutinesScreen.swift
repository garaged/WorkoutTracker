// File: Features/Routines/RoutinesScreen.swift
import SwiftUI
import SwiftData

struct RoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.updatedAt, order: .reverse)])
    private var routines: [WorkoutRoutine]

    var body: some View {
        List {
            if routines.isEmpty {
                ContentUnavailableView(
                    "No routines",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Create a routine so workouts can attach to it.")
                )
            } else {
                ForEach(routines) { r in
                    NavigationLink {
                        RoutineEditorScreen(mode: .edit(r))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.name).font(.headline)
                            Text("\(r.items.count) items")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Routines")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RoutineEditorScreen(mode: .create)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func delete(_ indexSet: IndexSet) {
        for i in indexSet {
            modelContext.delete(routines[i])
        }
        try? modelContext.save()
    }
}
