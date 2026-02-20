import Foundation
import SwiftData

@MainActor
enum StarterPackSeeder {
    // Bump when you expand/adjust the starter pack.
    private static let version = 1
    private static let key = "workouttracker.starterPackVersion"

    static func seedIfNeeded(context: ModelContext) {
        // Never interfere with UI tests — they already have explicit seeding.
        let env = ProcessInfo.processInfo.environment
        guard env["UITESTS"] != "1" else { return }

        let current = UserDefaults.standard.integer(forKey: key)
        guard current < version else { return }

        // Seed only when the user is "fresh" (avoid surprising existing users).
        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let routineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0
        guard exerciseCount == 0 && routineCount == 0 else {
            UserDefaults.standard.set(version, forKey: key)
            return
        }

        // Reuse your existing seeder (known to compile because your UI test boot uses it).
        do {
            _ = try RoutineSeeder.seedDemoDataIfEmpty(context: context)
            try context.save()
            UserDefaults.standard.set(version, forKey: key)
        } catch {
            assertionFailure("Starter pack seed failed: \(error)")
        }
    }
}
