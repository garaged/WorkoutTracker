// File: workouttracker/Features/Day/DayTimelineEntryScreen.swift
//
// Patch: add an initializer so other screens (like Routines) can open the Calendar at a specific day.
// This is a backwards-compatible change (existing call sites still compile).

import SwiftUI
import SwiftData

struct DayTimelineEntryScreen: View {
    private let cal = Calendar.current

    @Environment(\.modelContext) private var modelContext

    @State private var day: Date
    @State private var presentedSession: WorkoutSession? = nil

    @State private var editorRequest: ActivityEditorRequest? = nil

    private struct ActivityEditorRequest: Identifiable {
    // Using the Activity's id keeps the sheet stable for this specific object.
    // When the sheet dismisses, we set `editorRequest = nil`, so reopening works normally.
    let id: UUID
    let activity: Activity
    let isNew: Bool

    init(activity: Activity, isNew: Bool) {
        self.id = activity.id
        self.activity = activity
        self.isNew = isNew
    }
}

init(initialDay: Date = Date()) {
        _day = State(initialValue: initialDay)
    }

    private var dayStart: Date { cal.startOfDay(for: day) }
    private var isToday: Bool { cal.isDateInToday(day) }

    var body: some View {
        DayTimelineScreen(
            day: dayStart,
            presentedSession: $presentedSession,
            onEdit: { a in
                openEditor(for: a, isNew: false)
            },
            onCreateAt: { start, lane in
                let a = createActivity(start: start, end: nil, lane: lane)
                openEditor(for: a, isNew: true)
            },
            onCreateRange: { start, end, lane in
                let a = createActivity(start: start, end: end, lane: lane)
                openEditor(for: a, isNew: true)
            }
        )
        .navigationDestination(item: $presentedSession) { s in
            WorkoutSessionScreen(session: s)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { headerToolbar }
        .sheet(item: $editorRequest, onDismiss: {
            editorRequest = nil
        }) { req in
            ActivityEditorSheet(activity: req.activity, isNew: req.isNew)
        }
    }

    private var dayTitle: String {
        day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private var headerToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .principal) {
                Text(dayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .contentShape(Rectangle())
                    .onTapGesture { day = Date() }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left.circle")
                }
                .accessibilityLabel("Previous day")

                Button { day = Date() } label: {
                    Image(systemName: "calendar")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isToday ? Color.secondary : Color.accentColor)
                }
                .disabled(isToday)
                .accessibilityLabel("Go to today")

                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .accessibilityLabel("Next day")
            }
        }
    }

    private func shiftDay(_ delta: Int) {
        day = cal.date(byAdding: .day, value: delta, to: day) ?? day
    }

    private func openEditor(for a: Activity, isNew: Bool) {
        // Drive the sheet off an Identifiable item so it never presents “blank” on first open.
        editorRequest = ActivityEditorRequest(activity: a, isNew: isNew)
    }

    private func createActivity(start: Date, end: Date?, lane: Int) -> Activity {
        let cleanStart = start
        let computedEnd = end ?? cal.date(byAdding: .minute, value: 30, to: cleanStart)

        let a = Activity(
            title: "New Activity",
            startAt: cleanStart,
            endAt: computedEnd,
            laneHint: lane
        )
        a.dayKey = Self.dayKey(for: cleanStart)

        modelContext.insert(a)
        try? modelContext.save()
        return a
    }

    static func dayKey(for date: Date) -> String {
        let start = Calendar.current.startOfDay(for: date)
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }
}
