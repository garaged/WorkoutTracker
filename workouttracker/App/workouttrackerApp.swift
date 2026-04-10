import SwiftUI
import SwiftData
import UIKit
import Foundation
import AppIntents

@main
struct workouttrackerApp: App {
    @StateObject private var goalPrefill = GoalPrefillStore()   // ✅ keep one instance alive

    init() {
        let env = ProcessInfo.processInfo.environment
        if env["UITESTS"] == "1", env["UITESTS_RESET"] == "1",
           let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // ✅ WatchConnectivity should not run in UI tests (avoids extra flakiness + overhead).
        // Note: avoid capturing `self` from an escaping Task in a struct init.
        if env["UITESTS"] != "1" {
            WorkoutTrackerShortcutsProvider.updateAppShortcutParameters()

            let container = sharedModelContainer
            Task { @MainActor in
                WorkoutRemoteControlRouter.shared.start(modelContainer: container)
            }
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let env = ProcessInfo.processInfo.environment

        // ✅ UI tests: fast + deterministic
        if env["UITESTS"] == "1" {
            // UI tests: reduce flakiness and make runs deterministic.
            UIView.setAnimationsEnabled(false)

            if env["UITESTS_RESET"] == "1", let bid = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bid)
                UserDefaults.standard.synchronize()
            }

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

        #if DEBUG
        if env["DEBUG_RESET_STORE"] == "1" {
            nukeStoreFiles()
            PerformanceSeedInstaller.clearInstalledMarker()
        }
        #endif

        func buildPersistentContainer() throws -> ModelContainer {
            try ModelContainerFactory.makeOnDiskContainer(name: "default", storeURL: storeURL)
        }

        do {
            let container = try buildPersistentContainer()

            #if DEBUG
            if env["DEBUG_INSTALL_LARGE_SEED"] == "1" {
                let context = ModelContext(container)
                do {
                    try PerformanceSeedInstaller.installIfRequested(context: context, env: env)
                } catch {
                    fatalError("Could not install DEBUG large seed: \(error)")
                }
            }
            #endif

            return container
        } catch {
            #if DEBUG
            // Dev-only: schema changed, old store is incompatible -> wipe and retry once
            nukeStoreFiles()
            PerformanceSeedInstaller.clearInstalledMarker()
            do {
                let container = try buildPersistentContainer()

                if env["DEBUG_INSTALL_LARGE_SEED"] == "1" {
                    let context = ModelContext(container)
                    do {
                        try PerformanceSeedInstaller.installIfRequested(context: context, env: env)
                    } catch {
                        fatalError("Could not install DEBUG large seed after wiping store: \(error)")
                    }
                }

                return container
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
            let env = ProcessInfo.processInfo.environment
            if env["UITESTS"] == "1" {
                UITestStartRouter()
                    .environmentObject(goalPrefill)
            } else {
                AppRootView()
                    .environmentObject(goalPrefill)
                    .providePlatformContext()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - UI Test seed
@MainActor
private func seedForUITestsIfNeeded(context: ModelContext, calendar: Calendar = .current) throws {
    let existingActivities = try context.fetch(FetchDescriptor<Activity>())
    if !existingActivities.isEmpty { return }

    _ = try RoutineSeeder.seedDemoDataIfEmpty(context: context)

    // MARK: - Extra UI-test-only routines

    // Some UI regressions only reproduce with starter-pack cardio tracking (time / distance).
    // Instead of hand-building a special routine here, reuse the app's idempotent Starter Pack import.
    // This guarantees the routine names + tracking styles match production ("Starter — Cardio + Mobility", etc).
    _ = try RoutineSeeder.importStarterPack(context: context)


    let todayStart = calendar.startOfDay(for: Date())

    // Place seeded blocks near "now" so the calendar view doesn't have to scroll far to find them.
    let now = Date()
    let hm = calendar.dateComponents([.hour, .minute], from: now)
    let hour = hm.hour ?? 9
    let minute = hm.minute ?? 0
    let roundedMinute = (minute / 5) * 5

    let nearNowStart = calendar.date(
        bySettingHour: hour,
        minute: roundedMinute,
        second: 0,
        of: todayStart
    ) ?? todayStart

    let genericEnd = calendar.date(byAdding: .minute, value: 60, to: nearNowStart) ?? nearNowStart
    let timed = Activity(title: "UITest — Timed", startAt: nearNowStart, endAt: genericEnd, laneHint: 0, kind: .generic)
    context.insert(timed)

    let allDayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart)
    let allDay = Activity(title: "UITest — All-day", startAt: todayStart, endAt: allDayEnd, laneHint: 0, kind: .generic)
    allDay.isAllDay = true
    context.insert(allDay)

    // Seed one real workout activity for the starter-cardio layout smoke test.
    // This keeps the test independent from the routine-picker path.
    if let starterCardio = try? context.fetch(
        FetchDescriptor<WorkoutRoutine>(
            predicate: #Predicate<WorkoutRoutine> { routine in
                routine.name.contains("Cardio") && routine.name.contains("Mobility")
            }
        )
    ).first {
        let start = nearNowStart
        let end = calendar.date(byAdding: .minute, value: 45, to: start) ?? genericEnd
        let cardioActivity = Activity(
            title: "UITest — Seeded Starter Cardio",
            startAt: start,
            endAt: end,
            laneHint: 0,
            kind: .workout,
            workoutRoutineId: starterCardio.id
        )
        cardioActivity.dayKey = DayTimelineEntryScreen.dayKey(for: start)
        cardioActivity.status = .planned
        cardioActivity.completedAt = nil
        cardioActivity.isAllDay = false
        context.insert(cardioActivity)
    }

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
