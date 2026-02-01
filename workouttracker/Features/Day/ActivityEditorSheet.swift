import SwiftUI
import SwiftData

// File: workouttracker/Features/Day/ActivityEditorSheet.swift
//
// Why:
// - Editing/creating activities from the day timeline.
// - Local state so Cancel truly discards changes.
// - For new activities, Cancel deletes the created row to avoid junk.

struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: Activity
    let isNew: Bool

    // Routines are only relevant for workout activities.
    @Query(sort: \WorkoutRoutine.name) private var routines: [WorkoutRoutine]

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEndAt: Bool
    @State private var endAt: Date
    @State private var laneHint: Int
    @State private var status: ActivityStatus

    @State private var kind: ActivityKind
    @State private var routineId: UUID?

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

        _kind = State(initialValue: activity.kind)
        _routineId = State(initialValue: activity.workoutRoutineId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("activityEditor.titleField")

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
                    LabeledContent("Type") {
                        Picker("", selection: $kind) {
                            ForEach(ActivityKind.allCases, id: \.self) { k in
                                Text(String(describing: k).capitalized).tag(k)
                            }
                        }
                        .accessibilityIdentifier("activityEditor.typePicker")
                    }
                    
                    .onChange(of: kind) { _, newKind in
                        if newKind != .workout { routineId = nil }
                    }

                    if kind == .workout {
                        if routines.isEmpty {
                            Text("No routines yet. Create one in the Routines tab.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            LabeledContent("Routine") {
                                Picker("", selection: $routineId) {
                                    Text("Quick workout").tag(UUID?.none)
                                    ForEach(routines) { r in
                                        Text(r.name).tag(Optional(r.id))
                                    }
                                }
                                .accessibilityIdentifier("activityEditor.routinePicker")
                            }
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
                        .accessibilityIdentifier("activityEditor.cancelButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.headline)
                        .accessibilityIdentifier("activityEditor.saveButton")
                }
            }
        }
    }

    private func kindLabel(_ k: ActivityKind) -> String {
        let s = String(describing: k)
        return s.prefix(1).uppercased() + s.dropFirst()
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

        activity.kindRaw = kind.rawValue
        activity.workoutRoutineId = (kind == .workout) ? routineId : nil

        activity.dayKey = DayTimelineEntryScreen.dayKey(for: startAt)

        try? modelContext.save()
        dismiss()
    }
}
