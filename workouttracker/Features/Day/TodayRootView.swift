import SwiftUI
import SwiftData

struct TodayRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    private let cal = Calendar.current

    @State private var selectedDay: Date = Date()

    @State private var newDraft: NewActivityDraft?
    @State private var editingActivity: Activity?

    // ✅ Push routing
    enum Route: Hashable {
        case log
        case progress
        case routines
        case templates(applyDayKey: String) // keep Hashable stable
    }

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { selectedDay = cal.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay }
                    label: { Image(systemName: "chevron.left") }

                    Button("Today") { selectedDay = Date() }

                    Button { selectedDay = cal.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay }
                    label: { Image(systemName: "chevron.right") }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { path.append(.log) } label: {
                            Label("Workout Log", systemImage: "calendar")
                        }

                        Button { path.append(.progress) } label: {
                            Label("Progress", systemImage: "chart.bar")
                        }

                        Divider()

                        Button { path.append(.routines) } label: {
                            Label("Routines", systemImage: "list.bullet.rectangle")
                        }

                        Divider()

                        Button { path.append(.templates(applyDayKey: selectedDay.dayKey())) } label: {
                            Label("Templates", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        newDraft = NewActivityDraft(initialStart: nil, initialEnd: nil, laneHint: 0)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .log:
                    WorkoutLogScreen() // ✅ pushed

                case .progress:
                    WeekProgressScreen() // ✅ pushed

                case .routines:
                    RoutineEditorScreen() // or RoutinesScreen() if you have it

                case .templates(let applyDayKey):
                    // reconstruct Date from key if you want, or just pass selectedDay
                    TemplatesScreen(applyDay: selectedDay) // simplest; it’s still correct UX
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if !cal.isDateInToday(selectedDay) { selectedDay = Date() }
        }
        // ✅ Keep only editor sheets
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
    }

    private func dayTitle(_ d: Date) -> String {
        cal.isDateInToday(d) ? "Today" : d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

private struct NewActivityDraft: Identifiable {
    let id = UUID()
    let initialStart: Date?
    let initialEnd: Date?
    let laneHint: Int
}
