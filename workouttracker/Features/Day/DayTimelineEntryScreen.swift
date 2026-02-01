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

    @State private var editingActivity: Activity? = nil
    @State private var editorPresented: Bool = false
    @State private var editorIsNew: Bool = false

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
        .sheet(isPresented: $editorPresented, onDismiss: {
            editingActivity = nil
            editorIsNew = false
        }) {
            if let a = editingActivity {
                ActivityEditorSheet(activity: a, isNew: editorIsNew)
            }
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
        editingActivity = a
        editorIsNew = isNew
        editorPresented = true
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
