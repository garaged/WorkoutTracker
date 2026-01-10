import SwiftUI
import SwiftData

@main
struct workouttrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        // 1) Define which @Model types belong to this store
        let schema = Schema([
            Activity.self,
        ])

        // 2) Build a stable on-disk location (Application Support/default.store)
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        do {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        } catch {
            fatalError("Could not create Application Support directory: \(error)")
        }

        let storeURL = appSupport.appendingPathComponent("default.store")

        // 3) Create a configuration using the correct initializer for a custom URL
        //    NOTE: This initializer does NOT take isStoredInMemoryOnly.
        let modelConfiguration = ModelConfiguration(
            "default",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        // 4) Create the container (the “database engine” SwiftData uses)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TodayRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
