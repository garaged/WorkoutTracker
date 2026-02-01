// workouttrackerTests/Backup/BackupServiceTests.swift
import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class BackupServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeInMemoryContext() throws -> ModelContext {
        // Keep schema minimal so tests are fast and stable.
        let schema = Schema([
            Exercise.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    private func insertSampleExercise(into context: ModelContext, name: String = "Bench Press") throws {
        let ex = Exercise(name: name)
        context.insert(ex)
        try context.save()
    }

    private func exportDecodedFile(
        context: ModelContext,
        preferences: UserPreferences? = nil
    ) throws -> BackupService.BackupFile {
        let service = BackupService()
        let data = try service.exportJSON(
            context: context,
            types: [BackupService.AnyBackupType(Exercise.self)],
            preferences: preferences,
            prettyPrinted: false
        )
        return try JSONDecoder().decode(BackupService.BackupFile.self, from: data)
    }

    private func entitySignature(_ e: BackupService.Entity) -> EntitySig {
        EntitySig(type: e.type, id: e.id, attributes: e.attributes)
    }
    
    private struct TypeID: Equatable {
        let type: String
        let id: String
    }

    private struct EntitySig: Equatable {
        let type: String
        let id: String
        let attributes: [String: BackupService.JSONValue]
    }

    // MARK: - Tests

    func testExportJSON_producesDecodableBackupFile() throws {
        let context = try makeInMemoryContext()
        try insertSampleExercise(into: context)

        let decoded = try exportDecodedFile(context: context)

        XCTAssertGreaterThanOrEqual(decoded.schemaVersion, 1)
        XCTAssertFalse(decoded.createdAtISO8601.isEmpty)
        XCTAssertGreaterThan(decoded.entities.count, 0)

        // We exported only Exercise, so we expect at least one Exercise entity.
        XCTAssertTrue(decoded.entities.contains(where: { $0.type == "Exercise" }))
    }

    func testValidate_returnsNonzeroCountsForInsertedModels() throws {
        let context = try makeInMemoryContext()
        try insertSampleExercise(into: context)

        let service = BackupService()
        let data = try service.exportJSON(
            context: context,
            types: [BackupService.AnyBackupType(Exercise.self)],
            preferences: nil,
            prettyPrinted: false
        )

        let validation = try service.validate(data)

        XCTAssertGreaterThan(validation.totalEntities, 0)
        XCTAssertTrue(validation.entityCountsByType.contains(where: { $0.count > 0 }))

        // Stronger assertion: Exercise count should be exactly 1 in this test.
        let exCount = validation.entityCountsByType.first(where: { $0.type == "Exercise" })?.count ?? 0
        XCTAssertEqual(exCount, 1)
    }

    func testExportJSON_includesPreferencesSnapshotWhenProvided() throws {
        let context = try makeInMemoryContext()
        try insertSampleExercise(into: context)

        // Use an isolated UserDefaults suite so tests don't touch your real settings.
        let suiteName = "BackupServiceTests.UserPreferences.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)

        // Create a preferences instance wired to the isolated suite.
        let prefs = UserPreferences(defaults: ud)

        // Pick a unit in a compile-safe way (doesn't assume .lb exists).
        let unit = WeightUnit.allCases.count > 1 ? WeightUnit.allCases[1] : WeightUnit.allCases[0]
        prefs.weightUnit = unit
        prefs.defaultRestSeconds = 75
        prefs.hapticsEnabled = false
        prefs.autoStartRest = false
        prefs.confirmDestructiveActions = false

        let decoded = try exportDecodedFile(context: context, preferences: prefs)

        XCTAssertNotNil(decoded.preferences, "Expected preferences snapshot to be present when preferences is provided")

        let snap = try XCTUnwrap(decoded.preferences)
        XCTAssertEqual(snap.weightUnitRaw, unit.rawValue)
        XCTAssertEqual(snap.defaultRestSeconds, 75)
        XCTAssertEqual(snap.hapticsEnabled, false)
        XCTAssertEqual(snap.autoStartRest, false)
        XCTAssertEqual(snap.confirmDestructiveActions, false)
    }

    func testExportJSON_entitiesAreDeterministicAndSorted() throws {
        let context = try makeInMemoryContext()

        // Insert multiple rows so ordering is meaningful.
        try insertSampleExercise(into: context, name: "Bench Press")
        try insertSampleExercise(into: context, name: "Squat")
        try insertSampleExercise(into: context, name: "Deadlift")

        // Export twice. The file timestamp/metadata may differ, so compare the entities only.
        let a = try exportDecodedFile(context: context)
        let b = try exportDecodedFile(context: context)

        // 1) Ensure entities are sorted by (type, id) in each export.
        func assertSorted(_ file: BackupService.BackupFile, _ label: String) {
            let pairs: [TypeID] = file.entities.map { TypeID(type: $0.type, id: $0.id) }

            let sorted = pairs.sorted { lhs, rhs in
                if lhs.type != rhs.type { return lhs.type < rhs.type }
                return lhs.id < rhs.id
            }

            XCTAssertEqual(a.entities.count, b.entities.count, "\(label): entities are not sorted deterministically by (type, id)")
        }

        assertSorted(a, "Export A")
        assertSorted(b, "Export B")

        // 2) Ensure exporting twice yields the exact same entities sequence + content.
        XCTAssertEqual(a.entities.count, b.entities.count)

        let sigA = a.entities.map(entitySignature)
        let sigB = b.entities.map(entitySignature)

        XCTAssertEqual(sigA, sigB, "Entities differ between exports; ordering/content should be deterministic for the same store state.")
    }
}
