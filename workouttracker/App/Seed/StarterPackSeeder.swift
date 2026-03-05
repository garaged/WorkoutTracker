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

        // ✅ Robustness: never trust the version key if the store is empty.
        // This prevents a bad state where the key says "seeded" but the user has no routines/exercises
        // (e.g. older builds, a wiped store, or failed seed attempt).
        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let routineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0

        if exerciseCount == 0 && routineCount == 0 {
            do {
                _ = try RoutineSeeder.seedStarterPackIfNeeded(context: context)
                try context.save()
                UserDefaults.standard.set(version, forKey: key)
            } catch {
                // Leave the key untouched so the app can retry next launch.
                assertionFailure("Starter pack seed failed: \(error)")
            }
            return
        }

        // Store is not empty. If we bumped the version, mark it as "seen" so we don't keep checking.
        let current = UserDefaults.standard.integer(forKey: key)
        if current < version {
            UserDefaults.standard.set(version, forKey: key)
        }
    }
}
