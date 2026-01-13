import SwiftUI
import SwiftData

// File: Features/Routines/RoutinesScreen.swift
struct RoutinesScreen: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @State private var showNew = false
    @State private var showArchived = false

    private var filtered: [WorkoutRoutine] {
        routines
            .filter { showArchived ? true : !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No routines",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Create a routine, then attach it to a Workout activity or template.")
                    )
                } else {
                    ForEach(filtered) { r in
                        NavigationLink {
                            RoutineEditorScreen(mode: .edit(r))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(r.name).font(.headline)
                                if let notes = r.notes, !notes.isEmpty {
                                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("\(r.items.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            showArchived.toggle()
                        } label: {
                            Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                        }

                        Button {
                            showNew = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                NavigationStack {
                    RoutineEditorScreen(mode: .create)
                }
            }
        }
    }
}
