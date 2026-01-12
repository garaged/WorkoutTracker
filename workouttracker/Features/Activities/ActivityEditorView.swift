import SwiftUI
import SwiftData

struct ActivityEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\WorkoutRoutine.name, order: .forward)])
    private var routines: [WorkoutRoutine]

    private let cal = Calendar.current
    private let activity: Activity?
    private let day: Date
    private let initialStart: Date?
    private let initialEnd: Date?
    private let initialLaneHint: Int?

    // Opinionated: keep it small for now
    private let laneOptions: [Int] = [0, 1, 2]   // stored as 0-based
    private let laneLabels: [String] = ["Lane 1", "Lane 2", "Lane 3"]

    @State private var title: String
    @State private var startAt: Date
    @State private var hasEnd: Bool
    @State private var endAt: Date
    @State private var laneHint: Int
    @State private var isAllDay: Bool = false

    // ✅ Missing before: these must be initialized from the model (edit) or defaults (create)
    @State private var kind: ActivityKind
    @State private var workoutRoutineId: UUID?

    private var dayStart: Date { cal.startOfDay(for: startAt) }
    private var endDayStart: Date { cal.startOfDay(for: endAt) } // endAt used even for all-day

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if kind == .workout && workoutRoutineId == nil { return false }
        return true
    }

    init(
        day: Date,
        activity: Activity?,
        initialStart: Date?,
        initialEnd: Date?,
        initialLaneHint: Int?
    ) {
        self.day = day
        self.activity = activity
        self.initialStart = initialStart
        self.initialEnd = initialEnd
        self.initialLaneHint = initialLaneHint

        let fallbackStart = ActivityEditorView.defaultStart(for: day)
        let rawStart = activity?.startAt ?? (initialStart ?? fallbackStart)

        // ✅ all-day flag comes from model when editing, otherwise defaults false.
        let initialIsAllDay = activity?.isAllDay ?? false

        // Compute end candidates the same way you already do.
        let minEnd = cal.date(byAdding: .minute, value: 15, to: rawStart) ?? rawStart
        let proposedEnd =
            activity?.endAt
            ?? initialEnd
            ?? cal.date(byAdding: .minute, value: 30, to: rawStart)!

        // We'll finalize start/end depending on all-day.
        if initialIsAllDay {
            // Normalize all-day to day boundaries and end-exclusive midnight.
            let s = cal.startOfDay(for: rawStart)

            // If existing end is missing or invalid, default to +1 day.
            let rawEnd = activity?.endAt ?? proposedEnd
            var e = cal.startOfDay(for: rawEnd)

            if e <= s {
                e = cal.date(byAdding: .day, value: 1, to: s)!
            }

            _title = State(initialValue: activity?.title ?? "")
            _isAllDay = State(initialValue: true)

            _startAt = State(initialValue: s)
            _endAt = State(initialValue: e)

            // All-day always has an end (end-exclusive).
            _hasEnd = State(initialValue: true)
        } else {
            // Timed behavior unchanged
            let end = max(proposedEnd, minEnd)

            _title = State(initialValue: activity?.title ?? "")
            _isAllDay = State(initialValue: false)

            _startAt = State(initialValue: rawStart)
            _endAt = State(initialValue: end)

            // New activities default to end time (your current behavior)
            _hasEnd = State(initialValue: activity == nil ? true : (activity?.endAt != nil))
        }

        let initialLane =
            activity?.laneHint
            ?? initialLaneHint
            ?? 0
        _laneHint = State(initialValue: max(0, min(initialLane, 2))) // clamp to 0..2 for now

        // ✅ Critical: seed workout metadata from the model (edit) or defaults (create)
        _kind = State(initialValue: activity?.kind ?? .generic)
        _workoutRoutineId = State(initialValue: activity?.workoutRoutineId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                }

                Section("Type") {
                    Picker("Kind", selection: $kind) {
                        Text("Generic").tag(ActivityKind.generic)
                        Text("Workout").tag(ActivityKind.workout)
                    }
                    .pickerStyle(.segmented)

                    if kind == .workout && routines.isEmpty {
                        Text("Create a routine first to use Workout activities.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if kind == .workout {
                    Section("Workout") {
                        Picker("Routine", selection: $workoutRoutineId) {
                            Text("Choose…").tag(UUID?.none)
                            ForEach(routines) { r in
                                Text(r.name).tag(Optional(r.id))
                            }
                        }

                        if workoutRoutineId == nil {
                            Text("Pick a routine so tapping this block can Start/Resume a session.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Time") {
                    Toggle("All-day", isOn: $isAllDay)

                    if isAllDay {
                        DatePicker(
                            "Start date",
                            selection: Binding(
                                get: { cal.startOfDay(for: startAt) },
                                set: { newDate in
                                    let newStart = cal.startOfDay(for: newDate)

                                    let oldStart = cal.startOfDay(for: startAt)
                                    let oldEndExcl = cal.startOfDay(for: endAt)
                                    let days = max(1, cal.dateComponents([.day], from: oldStart, to: oldEndExcl).day ?? 1)

                                    startAt = newStart
                                    endAt = cal.date(byAdding: .day, value: days, to: newStart)!
                                    hasEnd = true
                                }
                            ),
                            displayedComponents: [.date]
                        )

                        DatePicker(
                            "End date",
                            selection: Binding(
                                get: {
                                    // inclusive = endExclusive - 1 day
                                    let endExcl = cal.startOfDay(for: endAt)
                                    return cal.date(byAdding: .day, value: -1, to: endExcl) ?? cal.startOfDay(for: startAt)
                                },
                                set: { newInclusive in
                                    let start = cal.startOfDay(for: startAt)
                                    let inclusive = cal.startOfDay(for: newInclusive)
                                    var endExclusive = cal.date(byAdding: .day, value: 1, to: inclusive)!

                                    if endExclusive <= start {
                                        endExclusive = cal.date(byAdding: .day, value: 1, to: start)!
                                    }
                                    endAt = endExclusive
                                    hasEnd = true
                                }
                            ),
                            in: cal.startOfDay(for: startAt)...,
                            displayedComponents: [.date]
                        )

                        Text("End date is inclusive (Calendar-style).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    } else {
                        DatePicker("Start", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                            .onChange(of: startAt) { _, newStart in
                                let minEnd = cal.date(byAdding: .minute, value: 15, to: newStart) ?? newStart
                                if endAt < minEnd {
                                    endAt = cal.date(byAdding: .minute, value: 30, to: newStart) ?? minEnd
                                }
                            }

                        Toggle("Set end time", isOn: $hasEnd)

                        if hasEnd {
                            DatePicker("End", selection: $endAt, in: minEndRange..., displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                }

                if !isAllDay {
                    Section("Lane") {
                        Picker("Lane", selection: $laneHint) {
                            ForEach(Array(zip(laneOptions, laneLabels)), id: \.0) { value, label in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Lane affects which column the block prefers when activities overlap.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(activity == nil ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            // ✅ Guardrails for workout selection
            .onChange(of: kind) { _, newKind in
                if newKind == .generic {
                    workoutRoutineId = nil
                } else {
                    // If user switches to Workout and nothing selected yet, pick first routine automatically.
                    if workoutRoutineId == nil, let first = routines.first {
                        workoutRoutineId = first.id
                    }
                    // If there are no routines, force back to generic (prevents dead-end state)
                    if routines.isEmpty {
                        kind = .generic
                        workoutRoutineId = nil
                    }
                }
            }
            .onChange(of: routines.count) { _, _ in
                // If routines list changes and we're in workout mode but no routine selected, auto-pick.
                if kind == .workout, workoutRoutineId == nil, let first = routines.first {
                    workoutRoutineId = first.id
                }
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .generic {
                    workoutRoutineId = nil
                } else {
                    // If user switches to workout and there are routines, auto-pick the first.
                    if workoutRoutineId == nil, let first = routines.first {
                        workoutRoutineId = first.id
                    }
                }
            }
        }
    }


    
    private var minEndRange: Date {
        cal.date(byAdding: .minute, value: 15, to: startAt) ?? startAt
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize fields we always persist
        func applyCommonFields(to a: Activity) {
            a.title = t
            a.laneHint = laneHint
            a.kind = kind
            if kind == .workout {
                a.workoutRoutineId = workoutRoutineId
            } else {
                a.workoutRoutineId = nil
            }
        }

        if isAllDay {
            // All-day uses date boundaries and always stores an end (end-exclusive)
            let startDay = cal.startOfDay(for: startAt)

            // endAt in state is already end-exclusive midnight from the UI binding,
            // but normalize defensively
            var endDayExclusive = cal.startOfDay(for: endAt)
            if endDayExclusive <= startDay {
                endDayExclusive = cal.date(byAdding: .day, value: 1, to: startDay)!
            }

            if let activity {
                applyCommonFields(to: activity)
                activity.isAllDay = true
                activity.startAt = startDay
                activity.endAt = endDayExclusive
            } else {
                let new = Activity(
                    title: t,
                    startAt: startDay,
                    endAt: endDayExclusive,
                    laneHint: laneHint,
                    kind: kind,
                    workoutRoutineId: (kind == .workout) ? workoutRoutineId : nil
                )
                new.isAllDay = true
                new.kind = kind
                new.workoutRoutineId = (kind == .workout) ? workoutRoutineId : nil
                applyCommonFields(to: new) // ✅ missing before: kind + routine on NEW activity
                modelContext.insert(new)
            }
        } else {
            // Timed behavior: preserve your old semantics
            let minEnd = cal.date(byAdding: .minute, value: 15, to: startAt) ?? startAt
            let finalEnd: Date? = hasEnd ? max(endAt, minEnd) : nil

            if let activity {
                applyCommonFields(to: activity)
                activity.isAllDay = false
                activity.startAt = startAt
                activity.endAt = finalEnd
            } else {
                let new = Activity(
                    title: t,
                    startAt: startAt,
                    endAt: finalEnd,
                    laneHint: laneHint,
                    kind: kind,
                    workoutRoutineId: (kind == .workout) ? workoutRoutineId : nil
                )
                new.isAllDay = false
                new.kind = kind
                new.workoutRoutineId = (kind == .workout) ? workoutRoutineId : nil
                applyCommonFields(to: new) // ✅ missing before: kind + routine on NEW activity
                modelContext.insert(new)
            }
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Activity: \(error)")
        }

        dismiss()
    }

    private static func defaultStart(for day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return Date() }

        let startOfDay = cal.startOfDay(for: day)
        return cal.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
    }
}
