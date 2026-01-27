import SwiftUI
import SwiftData

@main
struct workouttrackerApp: App {
    @State private var goalPrefill = GoalPrefillStore()

    var sharedModelContainer: ModelContainer = {
        let env = ProcessInfo.processInfo.environment

        // ✅ UI tests: fast + deterministic
        if env["UITESTS"] == "1" {
            do {
                let container = try ModelContainerFactory.makeInMemoryContainer()

                if env["UITESTS_SEED"] == "1" {
                    let context = ModelContext(container)
                    try? seedForUITestsIfNeeded(context: context)
                }

                return container
            } catch {
                fatalError("Could not create in-memory ModelContainer for UI tests: \(error)")
            }
        }

        // ✅ Real app: stable on-disk store
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        do {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        } catch {
            fatalError("Could not create Application Support directory: \(error)")
        }

        // Stable store location so we can delete it if needed
        let storeURL = appSupport.appendingPathComponent("default.store")

        func nukeStoreFiles() {
            // SwiftData/CoreData may create sidecar files too
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        }

        do {
            return try ModelContainerFactory.makeOnDiskContainer(name: "default", storeURL: storeURL)
        } catch {
            #if DEBUG
            // Dev-only: schema changed, old store is incompatible -> wipe and retry once
            nukeStoreFiles()
            do {
                return try ModelContainerFactory.makeOnDiskContainer(name: "default", storeURL: storeURL)
            } catch {
                fatalError("Could not create ModelContainer after wiping store: \(error)")
            }
            #else
            fatalError("Could not create ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            TodayRootView()
                .environment(goalPrefill)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - UI Test seed

@MainActor
private func seedForUITestsIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    // If we already seeded during this launch, or the store already has content, skip.
    let existingActivities = try context.fetch(FetchDescriptor<Activity>())
    if !existingActivities.isEmpty { return }

    // 1) Seed a demo routine (and exercises) so workout paths are available.
    _ = try RoutineSeeder.seedDemoDataIfEmpty(context: context)

    // 2) Add two activities for "today" in local calendar.
    let todayStart = calendar.startOfDay(for: Date())

    // Timed activity at 09:00 for visibility.
    let nineAM = calendar.date(byAdding: .hour, value: 9, to: todayStart) ?? todayStart
    let tenAM = calendar.date(byAdding: .hour, value: 10, to: todayStart) ?? nineAM
    let timed = Activity(title: "UITest — Timed", startAt: nineAM, endAt: tenAM, laneHint: 0, kind: .generic)
    context.insert(timed)

    // All-day activity.
    let allDayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
    let allDay = Activity(title: "UITest — All-day", startAt: todayStart, endAt: allDayEnd, laneHint: 0, kind: .generic)
    allDay.isAllDay = true
    context.insert(allDay)

    // 3) A template that matches daily so TemplatePreloader has something to work with.
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

    try context.save()
}
