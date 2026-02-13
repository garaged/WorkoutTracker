import SwiftUI
import SwiftData

@main
struct workouttrackerUITestHostApp: App {

    @StateObject private var goalPrefillStore = GoalPrefillStore()

    private let container: ModelContainer = {
        do { return try ModelContainerFactory.makeInMemoryContainer() }
        catch { fatalError("UITestHost: failed to create in-memory ModelContainer: \(error)") }
    }()

    var body: some Scene {
        WindowGroup {
            UITestHostRootView()
                .environmentObject(goalPrefillStore)
        }
        .modelContainer(container)
    }
}
