import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class BackupServiceTrackedActivityTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "BackupServiceTrackedActivityTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_exportBackupFile_includesTrackedActivityHealthExportMetadataAndAutoSavePreference() throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let service = BackupService()
        let preferences = UserPreferences(defaults: defaults)
        preferences.autoSaveCompletedTrackedActivitiesToAppleHealth = true

        let attemptedAt = Date(timeIntervalSince1970: 1_710_000_000)
        let succeededAt = attemptedAt.addingTimeInterval(15)
        let resumedAt = attemptedAt.addingTimeInterval(-120)
        let backgroundedAt = attemptedAt.addingTimeInterval(-30)
        let dismissedAt = attemptedAt.addingTimeInterval(45)
        let activeIntervalStartedAt = attemptedAt.addingTimeInterval(-60)
        let session = TrackedActivitySession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            createdAt: attemptedAt.addingTimeInterval(-300),
            updatedAt: succeededAt,
            startedAt: attemptedAt.addingTimeInterval(-240),
            endedAt: attemptedAt.addingTimeInterval(-10),
            activityKind: .running,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: 230,
                distanceMeters: 1450,
                activeEnergyKilocalories: 132,
                stepCount: 2100
            ),
            healthKitExportState: .exported,
            linkedActivityId: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
            notes: "Evening interval session",
            healthKitExportAttemptedAt: attemptedAt,
            healthKitExportSucceededAt: succeededAt,
            healthKitExportFailureMessage: nil,
            hasLocalChangesSinceHealthKitExport: true
        )
        session.activeIntervalStartedAt = activeIntervalStartedAt
        session.lastResumedAt = resumedAt
        session.lastBackgroundedAt = backgroundedAt
        session.dismissedRecoveryPromptAt = dismissedAt
        context.insert(session)
        try context.save()

        let backup = try service.exportBackupFile(
            context: context,
            types: BackupManifest.userDataTypes(),
            preferences: preferences
        )

        XCTAssertEqual(backup.preferences?.autoSaveCompletedTrackedActivitiesToAppleHealth, true)

        let entity = try XCTUnwrap(backup.entities.first(where: { $0.type == "TrackedActivitySession" }))
        assertString(entity.attributes["healthKitExportStateRaw"], equals: HealthKitExportState.exported.rawValue)
        assertISO8601Date(entity.attributes["healthKitExportAttemptedAt"], equals: attemptedAt)
        assertISO8601Date(entity.attributes["healthKitExportSucceededAt"], equals: succeededAt)
        assertNull(entity.attributes["healthKitExportFailureMessage"])
        assertBool(entity.attributes["hasLocalChangesSinceHealthKitExport"], equals: true)
        assertISO8601Date(entity.attributes["activeIntervalStartedAt"], equals: activeIntervalStartedAt)
        assertISO8601Date(entity.attributes["lastResumedAt"], equals: resumedAt)
        assertISO8601Date(entity.attributes["lastBackgroundedAt"], equals: backgroundedAt)
        assertISO8601Date(entity.attributes["dismissedRecoveryPromptAt"], equals: dismissedAt)
        assertString(entity.attributes["notes"], equals: "Evening interval session")
    }

    func test_restorePreferencesOnly_appliesAutoSavePreferenceSnapshot() throws {
        let service = BackupService()
        let sourcePreferences = UserPreferences(defaults: defaults)
        sourcePreferences.autoSaveCompletedTrackedActivitiesToAppleHealth = true

        let sourceContainer = try makeModelContainer()
        let sourceContext = ModelContext(sourceContainer)
        let data = try service.exportJSON(
            context: sourceContext,
            types: BackupManifest.userDataTypes(),
            preferences: sourcePreferences,
            prettyPrinted: false
        )

        let restoredSuite = "BackupServiceTrackedActivityTests.Restored.\(UUID().uuidString)"
        let restoredDefaults = UserDefaults(suiteName: restoredSuite)!
        restoredDefaults.removePersistentDomain(forName: restoredSuite)
        let restoredPreferences = UserPreferences(defaults: restoredDefaults)
        restoredPreferences.autoSaveCompletedTrackedActivitiesToAppleHealth = false

        try service.restorePreferencesOnly(data, preferences: restoredPreferences)

        XCTAssertTrue(restoredPreferences.autoSaveCompletedTrackedActivitiesToAppleHealth)

        restoredDefaults.removePersistentDomain(forName: restoredSuite)
    }

    func test_restoreWorkoutData_roundTripsTrackedActivityHealthExportMetadata() throws {
        let sourceContainer = try makeModelContainer()
        let sourceContext = ModelContext(sourceContainer)
        let service = BackupService()

        let attemptedAt = Date(timeIntervalSince1970: 1_710_100_000)
        let failureMessage = "Workout saved but route attachment failed."
        let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let linkedActivityID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

        let resumedAt = attemptedAt.addingTimeInterval(-180)
        let backgroundedAt = attemptedAt.addingTimeInterval(-90)
        let dismissedAt = attemptedAt.addingTimeInterval(30)
        let activeIntervalStartedAt = attemptedAt.addingTimeInterval(-30)
        let session = TrackedActivitySession(
            id: sessionID,
            createdAt: attemptedAt.addingTimeInterval(-600),
            updatedAt: attemptedAt,
            startedAt: attemptedAt.addingTimeInterval(-420),
            endedAt: attemptedAt.addingTimeInterval(-60),
            activityKind: .walking,
            environment: .outdoor,
            lifecycleState: .completed,
            totals: TrackedActivityTotals(
                elapsedDuration: 360,
                distanceMeters: 980,
                activeEnergyKilocalories: 84,
                stepCount: 1500
            ),
            healthKitExportState: .failed,
            linkedActivityId: linkedActivityID,
            notes: "Route attachment retry needed",
            healthKitExportAttemptedAt: attemptedAt,
            healthKitExportSucceededAt: nil,
            healthKitExportFailureMessage: failureMessage,
            hasLocalChangesSinceHealthKitExport: true
        )
        session.activeIntervalStartedAt = activeIntervalStartedAt
        session.lastResumedAt = resumedAt
        session.lastBackgroundedAt = backgroundedAt
        session.dismissedRecoveryPromptAt = dismissedAt
        sourceContext.insert(session)
        try sourceContext.save()

        let data = try service.exportJSON(
            context: sourceContext,
            types: BackupManifest.userDataTypes(),
            prettyPrinted: false
        )

        let restoredContainer = try makeModelContainer()
        let restoredContext = ModelContext(restoredContainer)
        try service.restoreWorkoutData(data, context: restoredContext)

        let restored = try restoredContext.fetch(FetchDescriptor<TrackedActivitySession>())
        XCTAssertEqual(restored.count, 1)

        let restoredSession = try XCTUnwrap(restored.first)
        XCTAssertEqual(restoredSession.id, sessionID)
        XCTAssertEqual(restoredSession.healthKitExportState, .failed)
        XCTAssertEqual(restoredSession.healthKitExportAttemptedAt, attemptedAt)
        XCTAssertNil(restoredSession.healthKitExportSucceededAt)
        XCTAssertEqual(restoredSession.healthKitExportFailureMessage, failureMessage)
        XCTAssertTrue(restoredSession.hasLocalChangesSinceHealthKitExport)
        XCTAssertEqual(restoredSession.activeIntervalStartedAt, activeIntervalStartedAt)
        XCTAssertEqual(restoredSession.lastResumedAt, resumedAt)
        XCTAssertEqual(restoredSession.lastBackgroundedAt, backgroundedAt)
        XCTAssertEqual(restoredSession.dismissedRecoveryPromptAt, dismissedAt)
        XCTAssertEqual(restoredSession.linkedActivityId, linkedActivityID)
        XCTAssertEqual(restoredSession.notes, "Route attachment retry needed")
        XCTAssertEqual(restoredSession.elapsedDuration, 360, accuracy: 0.001)
        XCTAssertEqual(restoredSession.distanceMeters ?? 0, 980, accuracy: 0.001)
        XCTAssertEqual(restoredSession.activeEnergyKilocalories ?? 0, 84, accuracy: 0.001)
        XCTAssertEqual(restoredSession.stepCount, 1500)
    }

    private func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutRoutine.self,
            WorkoutRoutineItem.self,
            WorkoutSetPlan.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            WorkoutSetLog.self,
            TrackedActivitySession.self,
            Activity.self,
            BodyMeasurement.self,
            TemplateActivity.self,
            TemplateInstanceOverride.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func assertString(_ value: BackupService.JSONValue?, equals expected: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .string(let actual)? = value else {
            XCTFail("Expected string JSON value \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertBool(_ value: BackupService.JSONValue?, equals expected: Bool, file: StaticString = #filePath, line: UInt = #line) {
        guard case .bool(let actual)? = value else {
            XCTFail("Expected bool JSON value \(expected)", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertNull(_ value: BackupService.JSONValue?, file: StaticString = #filePath, line: UInt = #line) {
        guard case .null? = value else {
            XCTFail("Expected null JSON value", file: file, line: line)
            return
        }
    }

    private func assertISO8601Date(_ value: BackupService.JSONValue?, equals expected: Date, file: StaticString = #filePath, line: UInt = #line) {
        guard case .string(let actual)? = value else {
            XCTFail("Expected ISO8601 string JSON value", file: file, line: line)
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        XCTAssertEqual(formatter.date(from: actual), expected, file: file, line: line)
    }
}
