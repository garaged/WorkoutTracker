// File: workouttracker/Features/Day/DayTimelineEntryScreen.swift

import SwiftUI
import SwiftData

struct DayTimelineEntryScreen: View {
    private let cal = Calendar.current

    @Environment(\.modelContext) private var modelContext

    @State private var day: Date
    @State private var presentedSession: WorkoutSession? = nil
    @State private var editorItem: EditorItem? = nil

    init(initialDay: Date = Date()) {
        _day = State(initialValue: initialDay)
    }

    private var dayStart: Date { cal.startOfDay(for: day) }
    private var isToday: Bool { cal.isDateInToday(day) }

    private var isUITesting: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["UITESTS"] == "1" || ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

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
        .sheet(item: $editorItem) { item in
            ActivityEditorSheet(activity: item.activity, isNew: item.isNew)
        }
        .overlay(alignment: .bottomTrailing) {
            // Test-only: stable entry point for "New Activity" without relying on SwiftUI header/toolbar accessibility.
            if isUITesting {
                Button {
                    createNewActivityFromUITestButton()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .padding(14)
                }
                .background(.thinMaterial, in: Circle())
                .shadow(radius: 4)
                .padding(16)
                .accessibilityIdentifier("timeline.newActivityButton")
                .accessibilityLabel("New activity")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Editor

    private struct EditorItem: Identifiable {
        let id = UUID()
        let activity: Activity
        let isNew: Bool
    }

    private func openEditor(for a: Activity, isNew: Bool) {
        editorItem = EditorItem(activity: a, isNew: isNew)
    }

    // MARK: - Toolbar

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
                Button { shiftDay(-1) } label: { Image(systemName: "chevron.left.circle") }
                    .accessibilityLabel("Previous day")

                Button { day = Date() } label: {
                    Image(systemName: "calendar")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isToday ? Color.secondary : Color.accentColor)
                }
                .disabled(isToday)
                .accessibilityLabel("Go to today")

                Button { shiftDay(1) } label: { Image(systemName: "chevron.right.circle") }
                    .accessibilityLabel("Next day")
            }
        }
    }

    private func shiftDay(_ delta: Int) {
        day = cal.date(byAdding: .day, value: delta, to: day) ?? day
    }

    // MARK: - Create

    private func createNewActivityFromUITestButton() {
        let start = defaultNewActivityStart()
        let a = createActivity(start: start, end: nil, lane: 0)
        openEditor(for: a, isNew: true)
    }

    private func defaultNewActivityStart() -> Date {
        // If we're looking at today, use "now rounded to 5 minutes".
        // If we're looking at another day, default to 08:00 on that day.
        let base = dayStart
        let now = Date()

        if cal.isDate(now, inSameDayAs: day) {
            let comps = cal.dateComponents([.hour, .minute], from: now)
            let hour = comps.hour ?? 8
            let minute = comps.minute ?? 0
            let rounded = (minute / 5) * 5
            return cal.date(bySettingHour: hour, minute: rounded, second: 0, of: base) ?? base
        } else {
            return cal.date(bySettingHour: 8, minute: 0, second: 0, of: base) ?? base
        }
    }

    private func createActivity(start: Date, end: Date?, lane: Int) -> Activity {
        let computedEnd = end ?? cal.date(byAdding: .minute, value: 30, to: start)

        let a = Activity(
            title: "New Activity",
            startAt: start,
            endAt: computedEnd,
            laneHint: lane
        )

        a.dayKey = Self.dayKey(for: start)

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
