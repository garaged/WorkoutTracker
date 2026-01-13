import SwiftUI
import SwiftData

@main
struct workouttrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Scheduling
            Activity.self,
            TemplateActivity.self,
            TemplateInstanceOverride.self,

            // Workouts / sessions
            WorkoutRoutine.self,
            WorkoutRoutineItem.self,
            WorkoutSetPlan.self,
            Exercise.self,
            
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self,
        ])
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        do {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        } catch {
            fatalError("Could not create Application Support directory: \(error)")
        }

        // Stable store location so we can delete it if needed
        let storeURL = appSupport.appendingPathComponent("default.store")

        let config = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        func nukeStoreFiles() {
            // SwiftData/CoreData may create sidecar files too
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            // Dev-only: schema changed, old store is incompatible -> wipe and retry once
            nukeStoreFiles()
            do {
                return try ModelContainer(for: schema, configurations: [config])
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
        }
        .modelContainer(sharedModelContainer)
    }
}
