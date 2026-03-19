import SwiftUI
import SwiftData

struct RoutineDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: WorkoutRoutine

    @State private var pickingExerciseForItem: WorkoutRoutineItem? = nil

    var body: some View {
        Form {
            Section {
                TextField(AppFormatting.localized("Name"), text: $routine.name)
                    .onChange(of: routine.name) { _, _ in touchUpdatedAndSave() }

                TextField(AppFormatting.localized("Notes"), text: Binding(
                    get: { routine.notes ?? "" },
                    set: { routine.notes = $0.isEmpty ? nil : $0; touchUpdatedAndSave() }
                ), axis: .vertical)
            } header: {
                Text(AppFormatting.localized("Routine"))
            }

            Section {
                linkedRoutineRow(title: AppFormatting.localized("Warm-up"), routine: routine.warmUpRoutine)
                linkedRoutineRow(title: AppFormatting.localized("Cool-down"), routine: routine.coolDownRoutine)
            } header: {
                Text(AppFormatting.localized("Linked routines"))
            }

            Section {
                if sortedItems.isEmpty {
                    ContentUnavailableView(AppFormatting.localized("No exercises yet"),
                        systemImage: "dumbbell",
                        description: Text(AppFormatting.localized("Add an item, pick an exercise, then set planned reps/weight/rest."))
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
                    Label(AppFormatting.localized("Add Exercise"), systemImage: "plus")
                }
            } header: {
                Text(AppFormatting.localized("Exercises"))
            }

            Section {
                Toggle(isOn: $routine.isArchived) {
                    Text(AppFormatting.localized("Archived"))
                }
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

    @ViewBuilder
    private func linkedRoutineRow(title: String, routine linkedRoutine: WorkoutRoutine?) -> some View {
        if let linkedRoutine {
            NavigationLink {
                RoutineDetailScreen(routine: linkedRoutine)
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Text(linkedRoutine.name)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            LabeledContent {
                Text(AppFormatting.localized("None"))
            } label: {
                Text(title)
            }
        }
    }

    private var sortedItems: [WorkoutRoutineItem] {
        routine.items.sorted { $0.order < $1.order }
    }

    @MainActor
    private func addItem() {
        let nextOrder = (sortedItems.last?.order ?? -1) + 1
        let item = WorkoutRoutineItem(order: nextOrder, routine: routine, exercise: nil, segmentRaw: WorkoutExerciseSegment.main.rawValue)
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
        item.exercise?.name ?? AppFormatting.localized("Pick exercise")
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

            TextField(AppFormatting.localized("Item notes (optional)"), text: Binding(
                get: { item.notes ?? "" },
                set: { item.notes = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .font(.caption)

            Picker(selection: Binding(
                get: { item.segment },
                set: {
                    item.segment = $0
                    onPlanChanged()
                }
            )) {
                ForEach(WorkoutExerciseSegment.allCases, id: \.self) { segment in
                    Text(segment.displayName).tag(segment)
                }
            } label: {
                Text(AppFormatting.localized("Segment"))
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppFormatting.localized("Planned sets")).font(.subheadline)
                    Spacer()
                    Button { onAddSet() } label: { Image(systemName: "plus.circle") }
                        .buttonStyle(.plain)
                }

                if sortedPlans.isEmpty {
                    Text(AppFormatting.localized("No sets planned."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlans) { plan in
                        WorkoutSetPlanEditorRow(plan: plan, onChanged: onPlanChanged)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    onDeleteSet(plan)
                                } label: {
                                    Label(AppFormatting.localized("Delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}
