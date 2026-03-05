import SwiftUI
import SwiftData
import Foundation
import UIKit

@main
@MainActor
struct workouttrackerUITestHostApp: App {

    @StateObject private var goalPrefillStore = GoalPrefillStore()

    private let container: ModelContainer

    init() {
        let env = ProcessInfo.processInfo.environment

        // Keep UI tests deterministic.
        UIView.setAnimationsEnabled(false)

        // Reset UserDefaults for the host bundle when requested.
        if env["UITESTS"] == "1", env["UITESTS_RESET"] == "1",
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        do {
            let c = try ModelContainerFactory.makeInMemoryContainer()

            // Calendar-style UI tests expect data seeded up-front. DayTimelineScreen intentionally
            // does NOT auto-seed on the "calendar" route (to avoid hijacking navigation).
            if env["UITESTS"] == "1", env["UITESTS_SEED"] == "1" {
                let context = ModelContext(c)
                try seedCalendarUITestDataIfNeeded(context: context)
            }

            self.container = c
        } catch {
            fatalError("UITestHost: failed to create/seed in-memory ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            UITestHostRootView()
                .environmentObject(goalPrefillStore)
        }
        .modelContainer(container)
    }
}

// MARK: - Calendar UITest seed
@MainActor
private func seedCalendarUITestDataIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    // 1) Always import Starter Pack (idempotent) so Workout picker has routines.
    _ = try RoutineSeeder.importStarterPack(context: context)

    // ✅ Fail fast in UI tests if the starter pack import didn’t create routines.
    // This turns "mysterious empty picker" into an immediate, actionable failure.
    let routineCount = try context.fetchCount(FetchDescriptor<WorkoutRoutine>())
    if routineCount == 0 {
        fatalError("UITESTS assertion failed: Starter Pack import created 0 WorkoutRoutine records. Ensure RoutineSeeder.swift + workout models are included in workouttrackerUITestHost target.")
    }

    // 2) Seed a few timeline items used by smoke tests (idempotent by title).
    let todayStart = calendar.startOfDay(for: Date())

    func ensureActivity(title: String, start: Date, end: Date?, kind: ActivityKind, workoutRoutineId: UUID? = nil, isAllDay: Bool = false) throws {
        let existing = try context.fetch(
            FetchDescriptor<Activity>(
                predicate: #Predicate<Activity> { a in a.title == title }
            )
        )
        if !existing.isEmpty { return }

        let a = Activity(title: title, startAt: start, endAt: end, laneHint: 0, kind: kind, workoutRoutineId: workoutRoutineId)
        a.isAllDay = isAllDay
        a.dayKey = DayTimelineEntryScreen.dayKey(for: start)
        context.insert(a)
    }

    // Place seeded items near the current hour so DayTimelineScreen auto-scroll lands close.
    let now = Date()
    let comps = calendar.dateComponents([.hour, .minute], from: now)
    let hour = comps.hour ?? 9
    let minute = ((comps.minute ?? 0) / 5) * 5
    let nearNow = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? todayStart

    try ensureActivity(
        title: "UITest — Timed",
        start: nearNow,
        end: calendar.date(byAdding: .minute, value: 60, to: nearNow),
        kind: .generic
    )

    try ensureActivity(
        title: "UITest — All-day",
        start: todayStart,
        end: calendar.date(byAdding: .day, value: 1, to: todayStart),
        kind: .generic,
        workoutRoutineId: nil,
        isAllDay: true
    )

    // Seed one real workout activity for the cardio layout test.
    let starterCardio = try context.fetch(
        FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate<WorkoutRoutine> { r in
                r.name.localizedStandardContains("Cardio") && r.name.localizedStandardContains("Mobility")
            }
        )
    ).first

    if let starterCardio {
        try ensureActivity(
            title: "UITest — Seeded Starter Cardio",
            start: nearNow,
            end: calendar.date(byAdding: .minute, value: 45, to: nearNow),
            kind: .workout,
            workoutRoutineId: starterCardio.id
        )
    } else {
        fatalError("UITESTS assertion failed: Expected to find a Starter cardio routine after Starter Pack import.")
    }

    // Template (kept because other calendar tests may rely on it)
    let existingTemplates = try context.fetchCount(FetchDescriptor<TemplateActivity>())
    if existingTemplates == 0 {
        let recurrence = RecurrenceRule(kind: .daily, startDate: todayStart, endDate: nil, interval: 1, weekdays: [])
        let template = TemplateActivity(
            title: "UITest — Template",
            defaultStartMinute: 7 * 60,
            defaultDurationMinutes: 30,
            isEnabled: true,
            recurrence: recurrence,
            kind: .generic
        )
        context.insert(template)
    }

    try context.save()
}
