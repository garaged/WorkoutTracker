import Foundation
import SwiftData

enum ModelContainerFactory {

    // MARK: - Single source of truth: Schema
    // *** If you add a new @Model and forget to add it here, you will eventually get runtime weirdness. ***
    private static let schema = Schema([
        // Scheduling
        Activity.self,
        TemplateActivity.self,
        TemplateInstanceOverride.self,

        // Workouts domain
        Exercise.self,
        WorkoutRoutine.self,
        WorkoutRoutineItem.self,
        WorkoutSetPlan.self,
        WorkoutSession.self,
        WorkoutSessionExercise.self,
        WorkoutSetLog.self,

        // Body
        BodyMeasurement.self
    ])

    // MARK: - Containers

    /// Fast + deterministic (previews/tests/uitests).
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Real app store (stable URL + name).
    static func makeOnDiskContainer(
        name: String = "default",
        storeURL: URL
    ) throws -> ModelContainer {
        let config = ModelConfiguration(
            name,
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
