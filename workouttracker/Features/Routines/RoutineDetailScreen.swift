import SwiftUI
import SwiftData

struct RoutineDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: WorkoutRoutine

    @State private var pickingExerciseForItem: WorkoutRoutineItem? = nil

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $routine.name)
                    .onChange(of: routine.name) { _, _ in touchUpdatedAndSave() }

                TextField("Notes", text: Binding(
                    get: { routine.notes ?? "" },
                    set: { routine.notes = $0.isEmpty ? nil : $0; touchUpdatedAndSave() }
                ), axis: .vertical)
            }

            Section("Exercises") {
                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        "No exercises yet",
                        systemImage: "dumbbell",
                        description: Text("Add an item, pick an exercise, then set planned reps/weight/rest.")
                    )
                }

                ForEach(sortedItems) { item in
                    RoutineItemCard(
                        item: item,
                        onPickExercise: { pickingExerciseForItem = item },
                        onAddSet: { addSetPlan(to: item) },
                        onDeleteSet: { plan in deleteSetPlan(in: item, plan: plan) },
                        onPlanChanged: { touchUpdatedAndSave() }
                    )
                }
                .onMove(perform: moveItems)

                Button {
                    addItem()
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            Section {
                Toggle("Archived", isOn: $routine.isArchived)
                    .onChange(of: routine.isArchived) { _, _ in touchUpdatedAndSave() }
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .sheet(item: $pickingExerciseForItem) { item in
            ExercisePickerSheet { ex in
                item.exercise = ex
                touchUpdatedAndSave()
            }
        }
        .onDisappear { touchUpdatedAndSave() }
    }

    private var sortedItems: [WorkoutRoutineItem] {
        routine.items.sorted { $0.order < $1.order }
    }

    @MainActor
    private func addItem() {
        let nextOrder = (sortedItems.last?.order ?? -1) + 1
        let item = WorkoutRoutineItem(order: nextOrder, routine: routine, exercise: nil)
        modelContext.insert(item)

        routine.items.append(item)

        // Opinionated default: add 3 planned sets so the editor feels “ready”
        for i in 0..<3 {
            let plan = WorkoutSetPlan(order: i, routineItem: item)
            modelContext.insert(plan)
            item.setPlans.append(plan)
        }

        touchUpdatedAndSave()
    }

    @MainActor
    private func moveItems(from: IndexSet, to: Int) {
        var arr = sortedItems
        arr.move(fromOffsets: from, toOffset: to)
        for (idx, it) in arr.enumerated() { it.order = idx }
        routine.items = arr
        touchUpdatedAndSave()
    }

    @MainActor
    private func addSetPlan(to item: WorkoutRoutineItem) {
        let next = (item.setPlans.map(\.order).max() ?? -1) + 1
        let plan = WorkoutSetPlan(order: next, routineItem: item)
        modelContext.insert(plan)
        item.setPlans.append(plan)
        touchUpdatedAndSave()
    }

    @MainActor
    private func deleteSetPlan(in item: WorkoutRoutineItem, plan: WorkoutSetPlan) {
        modelContext.delete(plan)

        var arr = item.setPlans.sorted { $0.order < $1.order }
        arr.removeAll { $0.id == plan.id }
        for (i, p) in arr.enumerated() { p.order = i }
        item.setPlans = arr

        touchUpdatedAndSave()
    }

    private func touchUpdatedAndSave() {
        routine.updatedAt = Date()
        do { try modelContext.save() }
        catch { assertionFailure("Routine save failed: \(error)") }
    }
}

private struct RoutineItemCard: View {
    @Bindable var item: WorkoutRoutineItem

    let onPickExercise: () -> Void
    let onAddSet: () -> Void
    let onDeleteSet: (WorkoutSetPlan) -> Void
    let onPlanChanged: () -> Void

    private var exerciseName: String {
        item.exercise?.name ?? "Pick exercise"
    }

    private var sortedPlans: [WorkoutSetPlan] {
        item.setPlans.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { onPickExercise() } label: {
                HStack {
                    Text(exerciseName)
                        .font(.headline)
                        .foregroundStyle(item.exercise == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            TextField("Item notes (optional)", text: Binding(
                get: { item.notes ?? "" },
                set: { item.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .font(.caption)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Planned sets").font(.subheadline)
                    Spacer()
                    Button { onAddSet() } label: { Image(systemName: "plus.circle") }
                        .buttonStyle(.plain)
                }

                if sortedPlans.isEmpty {
                    Text("No sets planned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlans) { plan in
                        WorkoutSetPlanEditorRow(plan: plan, onChanged: onPlanChanged)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteSet(plan)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
