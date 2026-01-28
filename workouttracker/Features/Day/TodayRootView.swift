import SwiftUI
import SwiftData

struct TodayRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    private let cal = Calendar.current

    @State private var selectedDay: Date = Date()

    @State private var newDraft: NewActivityDraft?
    @State private var editingActivity: Activity?
    @State private var presentedSession: WorkoutSession? = nil


    // ✅ Push routing
    enum Route: Hashable {
        case log
        case progress
        case routines
        case exercises
        case templates(applyDayKey: String) // keep Hashable stable
        case settings
    }

    @State private var path = NavigationPath()

    private var isToday: Bool { cal.isDateInToday(selectedDay) }

    var body: some View {
        NavigationStack(path: $path) {
            DayTimelineScreen(
                day: selectedDay,
                presentedSession: $presentedSession,
                onEdit: { editingActivity = $0 },
                onCreateAt: { start, lane in
                    newDraft = NewActivityDraft(initialStart: start, initialEnd: nil, laneHint: lane)
                },
                onCreateRange: { start, end, lane in
                    newDraft = NewActivityDraft(initialStart: start, initialEnd: end, laneHint: lane)
                }
            )
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
                guard presentedSession == nil else { return }

                do {
                    presentedSession = try UITestSeed.ensureInProgressSession(context: modelContext)
                } catch {
                    assertionFailure("UITest seed failed: \(error)")
                }
            }
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
                // ✅ Compact date stepper: < [calendar/today] >
                ToolbarItem(placement: .topBarLeading) {
                    DayStepperControl(
                        isToday: isToday,
                        goPrev: { shiftDay(-1) },
                        goToday: { selectedDay = Date() },
                        goNext: { shiftDay(1) }
                    )
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { path.append(Route.log) } label: {
                            Label("Workout Log", systemImage: "calendar")
                        }

                        Button { path.append(Route.progress) } label: {
                            Label("Progress", systemImage: "chart.bar")
                        }
                        
                        Button { path.append(Route.exercises) } label: {
                            Label("Exercises", systemImage: "dumbbell")
                        }

                        Divider()

                        Button { path.append(Route.routines) } label: {
                            Label("Routines", systemImage: "list.bullet.rectangle")
                        }

                        Divider()

                        Button { path.append(Route.templates(applyDayKey: selectedDay.dayKey())) } label: {
                            Label("Templates", systemImage: "wand.and.stars")
                        }
                        Divider()

                        Button { path.append(Route.settings) } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("nav.moreMenu")

                    Button {
                        newDraft = NewActivityDraft(initialStart: nil, initialEnd: nil, laneHint: 0)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("nav.addActivity")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .log:
                    WorkoutLogScreen(initialSelectedDay: selectedDay)

                case .progress:
                    WeekProgressScreen()

                case .routines:
                    RoutinesScreen()

                case .exercises:
                    ExerciseLibraryScreen()

                case .templates(let applyDayKey):
                    let applyDay = Date(dayKey: applyDayKey) ?? selectedDay
                    TemplatesScreen(applyDay: applyDay)
                
                case .settings:
                    PreferencesScreen()

                }
            }
            .navigationDestination(item: $presentedSession) { session in
                WorkoutSessionScreen(session: session)
                    .onDisappear { presentedSession = nil }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if !cal.isDateInToday(selectedDay) { selectedDay = Date() }
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
    }

    private func shiftDay(_ delta: Int) {
        selectedDay = cal.date(byAdding: .day, value: delta, to: selectedDay) ?? selectedDay
    }

    private func dayTitle(_ d: Date) -> String {
        if cal.isDateInToday(d) { return "Today" }

        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "MMM-dd-yy"
        return f.string(from: d)
    }

    // ✅ helper for stable routing
    private func dateFromDayKey(_ key: String) -> Date? {
        // key is "YYYY-MM-DD"
        let parts = key.split(separator: "-").map { Int($0) }
        guard parts.count == 3,
              let y = parts[0], let m = parts[1], let d = parts[2] else { return nil }

        var comps = DateComponents()
        comps.calendar = cal
        comps.timeZone = cal.timeZone
        comps.year = y
        comps.month = m
        comps.day = d

        // start-of-day in the same calendar/timezone
        return cal.date(from: comps).map { cal.startOfDay(for: $0) }
    }
}

private struct DayStepperControl: View {
    let isToday: Bool
    let goPrev: () -> Void
    let goToday: () -> Void
    let goNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: goPrev) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .accessibilityLabel("Previous day")
            .accessibilityIdentifier("dayStepper.prev")

            Button(action: goToday) {
                Image(systemName: isToday ? "calendar" : "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 4)
                    .foregroundStyle(isToday ? .secondary : .primary)
            }
            .accessibilityLabel("Go to Today")
            .accessibilityIdentifier("dayStepper.today")
            .disabled(isToday)
            .tint(.accentColor)

            Button(action: goNext) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 4)
            }
            .accessibilityLabel("Next day")
            .accessibilityIdentifier("dayStepper.next")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct NewActivityDraft: Identifiable {
    let id = UUID()
    let initialStart: Date?
    let initialEnd: Date?
    let laneHint: Int
}
