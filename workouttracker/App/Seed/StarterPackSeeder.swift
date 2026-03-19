import Foundation
import SwiftData

@MainActor
enum StarterPackSeeder {
    // Bump when you expand/adjust the starter pack.
    private static let version = 2
    private static let key = "workouttracker.starterPackVersion"

    static func seedIfNeeded(context: ModelContext) {
        let env = ProcessInfo.processInfo.environment
        guard env["UITESTS"] != "1" else { return }

        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        let routineCount  = (try? context.fetchCount(FetchDescriptor<WorkoutRoutine>())) ?? 0

        if exerciseCount == 0 && routineCount == 0 {
            do {
                _ = try RoutineSeeder.seedStarterPackIfNeeded(context: context)
                try context.save()
                UserDefaults.standard.set(version, forKey: key)
            } catch {
                assertionFailure("Starter pack seed failed: \(error)")
            }
            return
        }

        let current = UserDefaults.standard.integer(forKey: key)
        guard current < version else { return }

        do {
            _ = try RoutineSeeder.reconcileStarterExerciseCatalog(context: context)
            try context.save()
            UserDefaults.standard.set(version, forKey: key)
        } catch {
            assertionFailure("Starter pack reconciliation failed: \(error)")
        }
    }
}
