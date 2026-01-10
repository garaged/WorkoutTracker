import SwiftUI

struct TodayRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let cal = Calendar.current

    @State private var selectedDay: Date = Date()

    @State private var newDraft: NewActivityDraft?
    @State private var editingActivity: Activity?

    var body: some View {
        NavigationStack {
            DayTimelineScreen(
                day: selectedDay,
                onEdit: { activity in
                    editingActivity = activity
                },
                onCreateAt: { startAt in
                    newDraft = NewActivityDraft(initialStart: startAt)
                }
            )
            .navigationTitle(dayTitle(selectedDay))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                    } label: { Image(systemName: "chevron.left") }

                    Button("Today") { selectedDay = Date() }

                    Button {
                        selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                    } label: { Image(systemName: "chevron.right") }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newDraft = NewActivityDraft(initialStart: nil) // default (now or 9am)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // Snap to Today when returning to the app (handy when app left open overnight)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if !cal.isDateInToday(selectedDay) {
                selectedDay = Date()
            }
        }
        // New activity sheet (optionally prefilled start time)
        .sheet(item: $newDraft) { draft in
            ActivityEditorView(day: selectedDay, activity: nil, initialStart: draft.initialStart)
        }
        // Edit activity sheet
        .sheet(item: $editingActivity) { act in
            ActivityEditorView(day: selectedDay, activity: act, initialStart: nil)
        }
    }

    private func dayTitle(_ d: Date) -> String {
        if cal.isDateInToday(d) { return "Today" }
        return d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct NewActivityDraft: Identifiable {
    let id = UUID()
    let initialStart: Date?
}
