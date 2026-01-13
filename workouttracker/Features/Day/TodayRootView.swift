import SwiftUI
import SwiftData

struct TodayRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    private let cal = Calendar.current

    @State private var selectedDay: Date = Date()

    @State private var newDraft: NewActivityDraft?
    @State private var editingActivity: Activity?
    @State private var showTemplates = false
    @State private var showLog = false
    @State private var showProgress = false
    @State private var showRoutines = false

    var body: some View {
        NavigationStack {
            DayTimelineScreen(
                day: selectedDay,
                onEdit: { editingActivity = $0 },
                onCreateAt: { start, lane in
                    newDraft = NewActivityDraft(initialStart: start, initialEnd: nil, laneHint: lane)
                },
                onCreateRange: { start, end, lane in
                    newDraft = NewActivityDraft(initialStart: start, initialEnd: end, laneHint: lane)
                }
            )
            .task(id: selectedDay.dayKey()) {
                do {
                    try TemplatePreloader.ensureDayIsPreloaded(for: selectedDay, context: modelContext)
                } catch {
                    print("Preload failed: \(error)")
                }
            }
            .navigationTitle(dayTitle(selectedDay))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
                    } label: { Image(systemName: "chevron.left") }

                    TodayJumpButton(isToday: cal.isDateInToday(selectedDay)) {
                        selectedDay = Date()
                    }

                    Button {
                        selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
                    } label: { Image(systemName: "chevron.right") }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showLog = true
                        } label: {
                            Label("Workout Log", systemImage: "calendar")
                        }

                        Button {
                            showProgress = true
                        } label: {
                            Label("Progress", systemImage: "chart.bar")
                        }

                        Divider()

                        Button {
                            showRoutines = true
                        } label: {
                            Label("Routines", systemImage: "list.bullet.rectangle")
                        }

                        Divider()

                        Button {
                            showTemplates = true
                        } label: {
                            Label("Templates", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        let dayStart = cal.startOfDay(for: selectedDay)
                        let defaultStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? dayStart
                        newDraft = NewActivityDraft(initialStart: defaultStart, initialEnd: nil, laneHint: 0)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if !cal.isDateInToday(selectedDay) {
                selectedDay = Date()
            }
        }
        .sheet(item: $newDraft) { draft in
            ActivityEditorView(
                day: selectedDay,
                activity: nil,
                initialStart: draft.initialStart,
                initialEnd: draft.initialEnd,
                initialLaneHint: draft.laneHint
            )
        }
        .sheet(item: $editingActivity) { act in
            ActivityEditorView(
                day: selectedDay,
                activity: act,
                initialStart: nil,
                initialEnd: nil,
                initialLaneHint: nil
            )
        }
        .sheet(isPresented: $showTemplates) {
            TemplatesScreen(applyDay: selectedDay)
        }
        .sheet(isPresented: $showLog) {
            WorkoutLogScreen()
        }

        .sheet(isPresented: $showProgress) {
            WeekProgressScreen()
        }

        .sheet(isPresented: $showRoutines) {
            NavigationStack { RoutineEditorScreen() }
        }


    }

    private func dayTitle(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

private struct NewActivityDraft: Identifiable {
    let id = UUID()
    let initialStart: Date?
    let initialEnd: Date?
    let laneHint: Int
}
