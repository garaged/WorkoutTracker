// File: workouttracker/Features/Routines/RoutineEditorScreen.swift
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
    @State private var validationMessage: String? = nil

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
                    onAddExercise: { showExercisePicker = true }
                )
                .navigationTitle(isCreate ? "New Routine" : "Edit Routine")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent(for: routine) }
                .sheet(isPresented: $showExercisePicker) {
                    ExercisePickerSheet { picked in
                        guard let picked else { return }
                        pendingExerciseToAdd = picked
                        pendingTrackingStyle = defaultTrackingStyle(for: picked)
                        showExercisePicker = false
                        showTrackingStylePicker = true
                    }
                }
                .sheet(isPresented: $showTrackingStylePicker) {
                    TrackingStylePickerSheet(
                        exerciseName: pendingExerciseToAdd?.name ?? AppFormatting.localized("Exercise"),
                        selection: $pendingTrackingStyle
                    ) {
                        guard let ex = pendingExerciseToAdd else { return }
                        addExercise(ex, tracking: pendingTrackingStyle, to: routine)
                        pendingExerciseToAdd = nil
                    }
                }
                .alert(AppFormatting.localized("Linked routines"),
                    isPresented: Binding(
                        get: { validationMessage != nil },
                        set: { if !$0 { validationMessage = nil } }
                    )
                ) {
                    Button(AppFormatting.localized("OK"), role: .cancel) {}
                } message: {
                    Text(validationMessage ?? "")
                }
            } else {
                ProgressView()
                    .task { bootstrapIfNeeded() }
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(for routine: WorkoutRoutine) -> some ToolbarContent {
        if isCreate {
            ToolbarItem(placement: .topBarLeading) {
                Button(AppFormatting.localized("Cancel")) { cancelCreate() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(AppFormatting.localized("Save")) { saveAndDismiss() }
                    .disabled(cleanName(for: routine).isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button(AppFormatting.localized("Done")) { saveAndDismiss() }
                    .disabled(cleanName(for: routine).isEmpty)
            }
        }

        ToolbarItem(placement: .bottomBar) {
            if !isCreate {
                Button(role: .destructive) { deleteRoutine() } label: {
                    Label(AppFormatting.localized("Delete"), systemImage: "trash")
                }
            }
        }
    }

    @MainActor
    private func bootstrapIfNeeded() {
        guard routine == nil else { return }

        switch mode {
        case .create:
            // Draft only. Do not insert into SwiftData yet.
            routine = WorkoutRoutine(name: "")

        case .edit(let r):
            routine = r
        }
    }

    private func cancelCreate() {
        guard isCreate, let r = routine else {
            dismiss()
            return
        }

        // Only delete if the draft was actually inserted.
        if r.modelContext != nil {
            modelContext.delete(r)
            try? modelContext.save()
        }

        dismiss()
    }

    private func saveAndDismiss() {
        guard let r = routine else { return }

        switch RoutineLinkPlanner.validate(mainRoutine: r) {
        case .valid:
            break
        case .invalid(let message):
            validationMessage = message
            return
        }

        r.name = cleanName(for: r)
        r.notes = cleanNotes(for: r)
        r.updatedAt = Date()

        normalizeRoutineItemOrders(r)

        do {
            ensureRoutineInsertedIfNeeded(r)
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save routine: \(error)")
        }

        dismiss()
    }

    private func deleteRoutine() {
        guard let r = routine else { return }
        modelContext.delete(r)
        try? modelContext.save()
        dismiss()
    }

    private func addExercise(_ ex: Exercise, tracking style: ExerciseTrackingStyle, to routine: WorkoutRoutine) {
        // Insert the draft the first time we need persistent nested editing behavior.
        ensureRoutineInsertedIfNeeded(routine)

        let nextOrder = (routine.items.map(\.order).max() ?? -1) + 1

        let item = WorkoutRoutineItem(
            order: nextOrder,
            routine: routine,
            exercise: ex,
            notes: nil,
            trackingStyleRaw: style.rawValue,
            segmentRaw: WorkoutExerciseSegment.main.rawValue
        )

        let count = style.defaultPlannedRows
        if count > 0 {
            let sets = (0..<count).map { i in
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
            item.setPlans = sets
        } else {
            item.setPlans = []
        }

        routine.items.append(item)
        routine.updatedAt = Date()

        normalizeRoutineItemOrders(routine)
        try? modelContext.save()
    }

    private func ensureRoutineInsertedIfNeeded(_ routine: WorkoutRoutine) {
        guard routine.modelContext == nil else { return }
        modelContext.insert(routine)
    }

    private func normalizeRoutineItemOrders(_ routine: WorkoutRoutine) {
        let sorted = routine.items.sorted { $0.order < $1.order }
        for (idx, it) in sorted.enumerated() { it.order = idx }
    }

    private func defaultTrackingStyle(for exercise: Exercise) -> ExerciseTrackingStyle {
        switch exercise.modality {
        case .strength:
            return .strength
        case .timed, .mobility:
            return .timeOnly
        case .cardio:
            return .timeDistance
        }
    }

    private func cleanName(for routine: WorkoutRoutine) -> String {
        routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanNotes(for routine: WorkoutRoutine) -> String? {
        let trimmed = (routine.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct RoutineEditorDetail: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var routine: WorkoutRoutine

    let onAddExercise: () -> Void

    var body: some View {
        List {
            Section(AppFormatting.localized("Routine")) {
                TextField(AppFormatting.localized("Name"), text: Binding(
                    get: { routine.name },
                    set: { routine.name = $0; routine.updatedAt = Date() }
                ))

                TextField(AppFormatting.localized("Notes"), text: Binding(
                    get: { routine.notes ?? "" },
                    set: { routine.notes = $0.isEmpty ? nil : $0; routine.updatedAt = Date() }
                ), axis: .vertical)
                .lineLimit(2...6)
            }

            Section(AppFormatting.localized("Linked routines")) {
                LinkedRoutinePickerView(
                    role: .warmUp,
                    mainRoutineID: routine.id,
                    currentRoutine: routine.warmUpRoutine,
                    onSelect: { picked in
                        routine.warmUpRoutine = picked
                        routine.updatedAt = Date()
                    },
                    onClear: {
                        routine.warmUpRoutine = nil
                        routine.updatedAt = Date()
                    }
                )

                LinkedRoutinePickerView(
                    role: .coolDown,
                    mainRoutineID: routine.id,
                    currentRoutine: routine.coolDownRoutine,
                    onSelect: { picked in
                        routine.coolDownRoutine = picked
                        routine.updatedAt = Date()
                    },
                    onClear: {
                        routine.coolDownRoutine = nil
                        routine.updatedAt = Date()
                    }
                )
            }

            Section(AppFormatting.localized("Exercises")) {
                if routine.items.isEmpty {
                    ContentUnavailableView(AppFormatting.localized("No exercises"),
                        systemImage: "dumbbell",
                        description: Text(AppFormatting.localized("Add exercises so this routine can generate sessions."))
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
                    Label(AppFormatting.localized("Add exercise"), systemImage: "plus")
                }
            }

            Section(AppFormatting.localized("Status")) {
                Toggle(AppFormatting.localized("Archived"), isOn: Binding(
                    get: { routine.isArchived },
                    set: {
                        routine.isArchived = $0
                        routine.updatedAt = Date()
                    }
                ))
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

        if routine.modelContext != nil {
            try? modelContext.save()
        }
    }

    private func deleteItems(_ indexSet: IndexSet) {
        let sorted = itemsSorted

        if routine.modelContext != nil {
            for i in indexSet {
                let it = sorted[i]
                modelContext.delete(it)
            }
            routine.updatedAt = Date()
            try? modelContext.save()
        } else {
            let idsToRemove = Set(indexSet.map { sorted[$0].id })
            routine.items.removeAll { idsToRemove.contains($0.id) }

            let reordered = routine.items.sorted { $0.order < $1.order }
            for (idx, it) in reordered.enumerated() { it.order = idx }

            routine.updatedAt = Date()
        }
    }
}

private struct RoutineItemRow: View {
    let item: WorkoutRoutineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.exercise?.name ?? AppFormatting.localized("Unknown Exercise"))
                    .font(.headline)
                    .lineLimit(1)

                if item.segment != .main {
                    Text(item.segment.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var summaryText: String {
        let setCount = item.setPlans.count
        let label = setCount == 1 ? "1 set" : "\(setCount) sets"
        return "\(item.trackingStyle.displayName) • \(label)"
    }
}

// Make List/ForEach happy if needed
extension WorkoutRoutine: Identifiable {}
extension WorkoutRoutineItem: Identifiable {}
extension WorkoutSetPlan: Identifiable {}
