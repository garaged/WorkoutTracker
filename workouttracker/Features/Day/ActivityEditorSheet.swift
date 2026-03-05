import SwiftUI
import SwiftData
import Foundation

// File: workouttracker/Features/Day/ActivityEditorSheet.swift
//
// Fixes:
// - Persist a real default routine for Workout activities even if the user never touches the picker.
// - Auto-select the first available routine when switching to Workout.
// - Keep the existing accessibility identifiers used by UITests.

struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    @Bindable var activity: Activity
    let isNew: Bool

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEndAt: Bool
    @State private var endAt: Date
    @State private var laneHint: Int
    @State private var status: ActivityStatus

    @State private var kindRaw: String
    @State private var workoutRoutineId: UUID?

    init(activity: Activity, isNew: Bool) {
        self.activity = activity
        self.isNew = isNew

        _title = State(initialValue: activity.title)
        _startAt = State(initialValue: activity.startAt)

        if let e = activity.endAt {
            _hasEndAt = State(initialValue: true)
            _endAt = State(initialValue: e)
        } else {
            _hasEndAt = State(initialValue: false)
            _endAt = State(initialValue: Calendar.current.date(byAdding: .minute, value: 30, to: activity.startAt) ?? activity.startAt)
        }

        _laneHint = State(initialValue: activity.laneHint)
        _status = State(initialValue: activity.status)
        _kindRaw = State(initialValue: activity.kindRaw)
        _workoutRoutineId = State(initialValue: activity.workoutRoutineId)
    }

    private var normalizedKindRaw: String {
        kindRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isWorkout: Bool {
        normalizedKindRaw == "workout"
    }

    private var isUITesting: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["UITESTS"] == "1" || ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("activityEditor.titleField")


                    if isUITesting {
                        Button("UITest: Set Workout kind") {
                            kindRaw = "workout"
                            selectDefaultRoutineIfNeeded()
                        }
                        .accessibilityIdentifier("activityEditor.uitestSetWorkoutKind")
                    }

                    Picker("Status", selection: $status) {
                        Text("Planned").tag(ActivityStatus.planned)
                        Text("Done").tag(ActivityStatus.done)
                        Text("Skipped").tag(ActivityStatus.skipped)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $laneHint, in: 0...12) {
                        HStack {
                            Text("Lane")
                            Spacer()
                            Text("\(laneHint)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Start", selection: $startAt, displayedComponents: [.date, .hourAndMinute])

                    Toggle("Has end time", isOn: $hasEndAt)

                    if hasEndAt {
                        DatePicker("End", selection: $endAt, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Kind") {
                    Picker("Type", selection: $kindRaw) {
                        ForEach(kindOptions, id: \.raw) { opt in
                            Text(opt.label).tag(opt.raw)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("activityEditor.typePicker")
                    .onChange(of: kindRaw) { _, newRaw in
                        let normalized = newRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if normalized != "workout" {
                            workoutRoutineId = nil
                        } else {
                            selectDefaultRoutineIfNeeded()
                        }
                    }

                    if isWorkout {
                        if routines.isEmpty {
                            Text("No routines yet. Create one in Routines.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("activityEditor.routineEmptyState")
                        } else {
                            Picker("Routine", selection: Binding(
                                get: {
                                    if let workoutRoutineId {
                                        return Optional(workoutRoutineId)
                                    }
                                    return routines.first?.id
                                },
                                set: { workoutRoutineId = $0 }
                            )) {
                                ForEach(routines) { r in
                                    Text(r.name).tag(Optional(r.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("activityEditor.routinePicker")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        modelContext.delete(activity)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Label("Delete activity", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(isNew ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.headline)
                        .accessibilityIdentifier("activityEditor.saveButton")
                }
            }
            .onAppear {
                if isWorkout {
                    selectDefaultRoutineIfNeeded()
                }
            }
            .onChange(of: routines.count) { _, _ in
                if isWorkout {
                    selectDefaultRoutineIfNeeded()
                }
            }
        }
    }

    private var kindOptions: [(raw: String, label: String)] {
        var opts: [(String, String)] = [("generic", "Generic"), ("workout", "Workout")]
        let normalized = normalizedKindRaw
        if !opts.contains(where: { $0.0 == normalized }) && !normalized.isEmpty {
            opts.append((normalized, normalized.capitalized))
        }
        return opts
    }

    private func selectDefaultRoutineIfNeeded() {
        guard workoutRoutineId == nil else { return }
        workoutRoutineId = routines.first?.id
    }

    private func cancel() {
        if isNew {
            modelContext.delete(activity)
            try? modelContext.save()
        }
        dismiss()
    }

    private func save() {
        activity.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.startAt = startAt
        activity.endAt = hasEndAt ? endAt : nil
        activity.laneHint = laneHint
        activity.status = status

        activity.kindRaw = normalizedKindRaw
        if isWorkout {
            if workoutRoutineId == nil {
                selectDefaultRoutineIfNeeded()
            }
            activity.workoutRoutineId = workoutRoutineId
        } else {
            activity.workoutRoutineId = nil
        }
        activity.dayKey = DayTimelineEntryScreen.dayKey(for: startAt)

        try? modelContext.save()
        dismiss()
    }
}
