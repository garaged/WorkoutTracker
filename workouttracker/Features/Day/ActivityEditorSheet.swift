import SwiftUI
import SwiftData

// File: workouttracker/Features/Day/ActivityEditorSheet.swift
//
// Why this exists:
// - DayTimelineEntryScreen needs a real UI to edit / create activities.
// - We keep this as a standalone sheet so it can be reused later
//   (e.g., editing from a list view, templates, etc.).
//
// Design choice (important):
// - The sheet uses LOCAL state and only writes back on Save.
//   This gives you a real “Cancel” that discards changes.
// - For newly-created activities, Cancel deletes the activity so you don’t keep junk rows.

struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var activity: Activity
    let isNew: Bool

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEndAt: Bool
    @State private var endAt: Date
    @State private var laneHint: Int
    @State private var status: ActivityStatus

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
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

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
                    // Read-only for now (keeps this sheet resilient even if ActivityKind evolves).
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(activity.kindRaw.capitalized)
                            .foregroundStyle(.secondary)
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
                }
            }
        }
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

        // Keep the dayKey updated so your “day bucket” fetches stay correct.
        activity.dayKey = DayTimelineEntryScreen.dayKey(for: startAt)

        try? modelContext.save()
        dismiss()
    }
}
