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
        .toolbar { headerToolbar }
        .safeAreaInset(edge: .top, alignment: .trailing) {
            // XCUITest reliability: SwiftUI toolbar items often don't expose identifiers.
            // Provide a stable, view-hierarchy button only in UITESTS mode.
            if ProcessInfo.processInfo.environment["UITESTS"] == "1" {
                Button { createNewActivityFromToolbar() } label: {
                    Label("New activity", systemImage: "plus.circle")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("timeline.newActivityButton")
                .padding(.trailing, 8)
                .padding(.top, 6)
            }
        }
        .safeAreaInset(edge: .top, alignment: .trailing) {
            if ProcessInfo.processInfo.environment["UITESTS"] == "1" {
                Button { createNewActivityFromToolbar() } label: {
                    Label("New activity", systemImage: "plus.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .padding(.top, 6)
            }
        }
        .sheet(item: $editingActivity, onDismiss: {
            editorIsNew = false
        }) { a in
            ActivityEditorSheet(activity: a, isNew: editorIsNew)
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
                Button { createNewActivityFromToolbar() } label: {
                    Image(systemName: "plus.circle")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("New activity")
                .accessibilityIdentifier("timeline.newActivityButton")

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
    
    private func createNewActivityFromToolbar() {
            let start = defaultNewActivityStart()
            let a = createActivity(start: start, end: nil, lane: 0)
            openEditor(for: a, isNew: true)
        }

        private func defaultNewActivityStart() -> Date {
            if isToday {
                // Next 15-minute slot from “now”
                let now = Date()
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                let minute = comps.minute ?? 0
                let rounded = ((minute + 14) / 15) * 15
                var start = cal.date(from: comps) ?? now
                start = cal.date(bySetting: .minute, value: min(rounded, 59), of: start) ?? start
                return start
            } else {
                // 9:00am on the selected day
                return cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart
            }
        }
}
