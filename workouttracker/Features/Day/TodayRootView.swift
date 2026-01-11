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

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showTemplates = true } label: {
                        Image(systemName: "wand.and.stars")
                    }

                    Button {
                        newDraft = NewActivityDraft(initialStart: nil, initialEnd: nil, laneHint: 0)
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

    }

    private func dayTitle(_ d: Date) -> String {
        cal.isDateInToday(d) ? "Today" : d.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct NewActivityDraft: Identifiable {
    let id = UUID()
    let initialStart: Date?
    let initialEnd: Date?
    let laneHint: Int
}
