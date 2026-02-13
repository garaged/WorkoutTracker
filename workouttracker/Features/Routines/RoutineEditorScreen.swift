// File: Features/Routines/RoutineEditorScreen.swift
import SwiftUI
import SwiftData

struct RoutineEditorScreen: View {
    enum Mode {
        case create
        case edit(WorkoutRoutine)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let mode: Mode
    private let isCreate: Bool

    @State private var routine: WorkoutRoutine? = nil
    @State private var showExercisePicker = false
    
    @State private var pendingExerciseToAdd: Exercise? = nil
    @State private var pendingTrackingStyle: ExerciseTrackingStyle = .strength
    @State private var showTrackingStylePicker = false
    
    init(mode: Mode = .create) {
        self.mode = mode
        switch mode {
        case .create: self.isCreate = true
        case .edit: self.isCreate = false
        }
    }

    var body: some View {
        Group {
            if let routine {
                RoutineEditorDetail(
                    routine: routine,
                    onAddExercise: { showExercisePicker = true },
                    onDeleteRoutine: deleteRoutine
                )
                .navigationTitle(isCreate ? "New Routine" : "Edit Routine")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { cancel() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { save() }
                            .disabled(routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        if !isCreate {
                            Button(role: .destructive) { deleteRoutine() } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showExercisePicker) {
                    ExercisePickerSheet { picked in
                        guard let picked else { return }
                        pendingExerciseToAdd = picked
                        pendingTrackingStyle = .strength
                        showTrackingStylePicker = true
                    }
                }
                .sheet(isPresented: $showTrackingStylePicker) {
                    TrackingStylePickerSheet(
                        exerciseName: pendingExerciseToAdd?.name ?? "Exercise",
                        selection: $pendingTrackingStyle
                    ) {
                        guard let ex = pendingExerciseToAdd, let routine else { return }
                        addExercise(ex, tracking: pendingTrackingStyle, to: routine)
                        pendingExerciseToAdd = nil
                        showTrackingStylePicker = false
                    }
                }
            } else {
                ProgressView()
                    .task { bootstrapIfNeeded() }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() {
        guard routine == nil else { return }

        switch mode {
        case .create:
            let r = WorkoutRoutine(name: "")
            modelContext.insert(r)
            routine = r

        case .edit(let r):
            routine = r
        }
    }

    private func cancel() {
        if isCreate, let r = routine {
            modelContext.delete(r)
            try? modelContext.save()
        }
        dismiss()
    }

    private func save() {
        guard let r = routine else { return }
        r.updatedAt = Date()

        // Keep ordering stable
        normalizeRoutineItemOrders(r)

        do { try modelContext.save() }
        catch { assertionFailure("Failed to save routine: \(error)") }

        dismiss()
    }

    private func deleteRoutine() {
        guard let r = routine else { return }
        modelContext.delete(r)
        try? modelContext.save()
        dismiss()
    }

    private func addExercise(_ ex: Exercise, tracking style: ExerciseTrackingStyle, to routine: WorkoutRoutine) {
        let nextOrder = (routine.items.map(\.order).max() ?? -1) + 1
        let item = WorkoutRoutineItem(order: nextOrder, routine: routine, exercise: ex, notes: nil)

        item.trackingStyle = style

        let rows = style.defaultPlannedRows
        if rows > 0 {
            let plans = (0..<rows).map { i in
                WorkoutSetPlan(
                    order: i,
                    targetReps: nil,
                    targetWeight: nil,
                    weightUnit: .kg,
                    targetRPE: nil,
                    restSeconds: 90,
                    routineItem: item
                )
            }
            item.setPlans = plans
        } else {
            item.setPlans = []
        }

        routine.items.append(item)
        routine.updatedAt = Date()

        normalizeRoutineItemOrders(routine)
        try? modelContext.save()
    }

    private func normalizeRoutineItemOrders(_ routine: WorkoutRoutine) {
        let sorted = routine.items.sorted { $0.order < $1.order }
        for (idx, it) in sorted.enumerated() { it.order = idx }
    }
}

private struct RoutineEditorDetail: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: WorkoutRoutine

    let onAddExercise: () -> Void
    let onDeleteRoutine: () -> Void

    var body: some View {
        List {
            Section("Routine") {
                TextField("Name", text: Binding(
                    get: { routine.name },
                    set: { routine.name = $0; routine.updatedAt = Date() }
                ))

                TextField("Notes", text: Binding(
                    get: { routine.notes ?? "" },
                    set: { routine.notes = $0.isEmpty ? nil : $0; routine.updatedAt = Date() }
                ), axis: .vertical)
                .lineLimit(2...6)
            }

            Section("Exercises") {
                if routine.items.isEmpty {
                    ContentUnavailableView(
                        "No exercises",
                        systemImage: "dumbbell",
                        description: Text("Add exercises so this routine can generate sessions.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(itemsSorted) { item in
                        NavigationLink {
                            RoutineItemEditorScreen(item: item)
                        } label: {
                            RoutineItemRow(item: item)
                        }
                    }
                    .onMove(perform: moveItems)
                    .onDelete(perform: deleteItems)
                }

                Button {
                    onAddExercise()
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
    }

    private var itemsSorted: [WorkoutRoutineItem] {
        routine.items.sorted { $0.order < $1.order }
    }

    private func moveItems(from: IndexSet, to: Int) {
        var sorted = itemsSorted
        sorted.move(fromOffsets: from, toOffset: to)
        for (idx, it) in sorted.enumerated() { it.order = idx }
        routine.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteItems(_ indexSet: IndexSet) {
        let sorted = itemsSorted
        for i in indexSet {
            let it = sorted[i]
            modelContext.delete(it)
        }
        routine.updatedAt = Date()
        try? modelContext.save()
    }
}

private struct RoutineItemRow: View {
    let item: WorkoutRoutineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.exercise?.name ?? "Unknown Exercise")
                .font(.headline)
                .lineLimit(1)

            Text("\(item.setPlans.count) sets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// Make List/ForEach happy if needed
extension WorkoutRoutine: Identifiable {}
extension WorkoutRoutineItem: Identifiable {}
extension WorkoutSetPlan: Identifiable {}
