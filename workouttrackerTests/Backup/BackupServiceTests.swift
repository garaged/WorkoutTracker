// workouttrackerTests/Backup/BackupServiceTests.swift
import XCTest
import SwiftData
@testable import workouttracker

@MainActor
final class BackupServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeExerciseOnlyContext() throws -> ModelContext {
        // Keep the lightweight/export-shape tests minimal and fast.
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

    // MARK: - Round-trip helpers

    private func fullWorkoutBackupTypes() -> [BackupService.AnyBackupType] {
        [
            .init(Exercise.self),
            .init(WorkoutRoutine.self),
            .init(WorkoutRoutineItem.self),
            .init(WorkoutSetPlan.self),
            .init(WorkoutSession.self),
            .init(WorkoutSessionExercise.self),
            .init(WorkoutSetLog.self)
        ]
    }

    private func wipeWorkoutGraph(from context: ModelContext) throws {
        try deleteAll(WorkoutSetLog.self, from: context)
        try deleteAll(WorkoutSessionExercise.self, from: context)
        try deleteAll(WorkoutSession.self, from: context)
        try deleteAll(WorkoutSetPlan.self, from: context)
        try deleteAll(WorkoutRoutineItem.self, from: context)
        try deleteAll(WorkoutRoutine.self, from: context)
        try deleteAll(Exercise.self, from: context)
        try context.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, from context: ModelContext) throws {
        let rows = try context.fetch(FetchDescriptor<T>())
        for row in rows {
            context.delete(row)
        }
    }

    private func fetchAll<T: PersistentModel>(
        _ type: T.Type,
        from context: ModelContext
    ) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    // MARK: - Tests

    func testExportJSON_producesDecodableBackupFile() throws {
        let context = try makeExerciseOnlyContext()
        try insertSampleExercise(into: context)

        let decoded = try exportDecodedFile(context: context)

        XCTAssertGreaterThanOrEqual(decoded.schemaVersion, 4)
        XCTAssertFalse(decoded.createdAtISO8601.isEmpty)
        XCTAssertGreaterThan(decoded.entities.count, 0)

        XCTAssertTrue(decoded.entities.contains(where: { $0.type == "Exercise" }))
    }

    func testValidate_returnsNonzeroCountsForInsertedModels() throws {
        let context = try makeExerciseOnlyContext()
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

        let exCount = validation.entityCountsByType.first(where: { $0.type == "Exercise" })?.count ?? 0
        XCTAssertEqual(exCount, 1)
    }

    func testExportJSON_includesPreferencesSnapshotWhenProvided() throws {
        let context = try makeExerciseOnlyContext()
        try insertSampleExercise(into: context)

        let suiteName = "BackupServiceTests.UserPreferences.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)

        let prefs = UserPreferences(defaults: ud)

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
        let context = try makeExerciseOnlyContext()

        try insertSampleExercise(into: context, name: "Bench Press")
        try insertSampleExercise(into: context, name: "Squat")
        try insertSampleExercise(into: context, name: "Deadlift")

        let a = try exportDecodedFile(context: context)
        let b = try exportDecodedFile(context: context)

        func assertSorted(_ file: BackupService.BackupFile, _ label: String) {
            let pairs: [TypeID] = file.entities.map { TypeID(type: $0.type, id: $0.id) }

            let sorted = pairs.sorted { lhs, rhs in
                if lhs.type != rhs.type { return lhs.type < rhs.type }
                return lhs.id < rhs.id
            }

            XCTAssertEqual(pairs, sorted, "\(label): entities are not sorted deterministically by (type, id)")
        }

        assertSorted(a, "Export A")
        assertSorted(b, "Export B")

        XCTAssertEqual(a.entities.count, b.entities.count)

        let sigA = a.entities.map(entitySignature)
        let sigB = b.entities.map(entitySignature)

        XCTAssertEqual(sigA, sigB, "Entities differ between exports; ordering/content should be deterministic for the same store state.")
    }

    func testRestoreWorkoutData_restoresOlderBackupWithoutLinkedRoutineOrSegmentFields() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let service = BackupService()

        let routineID = UUID()
        let sessionID = UUID()
        let sessionExerciseID = UUID()
        let exerciseID = UUID()

        let file = BackupService.BackupFile(
            schemaVersion: 3,
            createdAtISO8601: "2026-02-10T07:00:00Z",
            metadata: nil,
            preferences: nil,
            entities: [
                BackupService.Entity(
                    type: "WorkoutRoutine",
                    id: routineID.uuidString,
                    attributes: [
                        "id": .string(routineID.uuidString),
                        "name": .string("Recovered Routine"),
                        "isArchived": .bool(false),
                        "createdAt": .string("2026-02-09T07:00:00Z"),
                        "updatedAt": .string("2026-02-09T07:00:00Z")
                    ]
                ),
                BackupService.Entity(
                    type: "WorkoutSession",
                    id: sessionID.uuidString,
                    attributes: [
                        "id": .string(sessionID.uuidString),
                        "startedAt": .string("2026-02-10T07:00:00Z"),
                        "statusRaw": .string(WorkoutSessionStatus.inProgress.rawValue),
                        "isPaused": .bool(false),
                        "accumulatedPausedSeconds": .number(0)
                    ]
                ),
                BackupService.Entity(
                    type: "WorkoutSessionExercise",
                    id: sessionExerciseID.uuidString,
                    attributes: [
                        "id": .string(sessionExerciseID.uuidString),
                        "order": .number(0),
                        "exerciseId": .string(exerciseID.uuidString),
                        "exerciseNameSnapshot": .string("Recovered Exercise"),
                        "trackingStyleRaw": .string(ExerciseTrackingStyle.strength.rawValue),
                        "session": .object([
                            "$ref": .string(sessionID.uuidString),
                            "$type": .string("WorkoutSession")
                        ])
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(file)
        try service.restoreWorkoutData(data, context: context)

        let sessions = try fetchAll(WorkoutSession.self, from: context)
        XCTAssertEqual(sessions.count, 1)

        let routines = try fetchAll(WorkoutRoutine.self, from: context)
        XCTAssertEqual(routines.count, 1)
        XCTAssertNil(routines[0].warmUpRoutine)
        XCTAssertNil(routines[0].coolDownRoutine)

        let exercises = try fetchAll(WorkoutSessionExercise.self, from: context)
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises[0].segment, .main)
        XCTAssertEqual(exercises[0].segmentRaw, WorkoutExerciseSegment.main.rawValue)
    }

    func testRestoreWorkoutData_roundTripsFullWorkoutGraph() throws {
        let store = try TestSupport.makeInMemoryStore()
        let context = store.context
        let service = BackupService()

        let startedAt = TestSupport.date(2026, 2, 10, 7, 0)
        let finishedAt = startedAt.addingTimeInterval(45 * 60)

        // Seed exercises
        let bench = Exercise(
            name: "Bench Press",
            instructions: "Pause on chest",
            notes: "Competition grip",
            equipmentTagsRaw: "barbell,bench"
        )
        bench.createdAt = TestSupport.date(2026, 1, 1, 8, 0)
        bench.updatedAt = TestSupport.date(2026, 1, 2, 8, 0)

        let row = Exercise(
            name: "Chest Supported Row",
            instructions: "Control the eccentric",
            notes: "Use neutral grip",
            equipmentTagsRaw: "dumbbell,bench"
        )

        context.insert(bench)
        context.insert(row)

        // Seed routines
        let warmUpRoutine = WorkoutRoutine(
            name: "Upper Warm-Up",
            notes: "Prep shoulders",
            isArchived: false
        )
        let routine = WorkoutRoutine(
            name: "Upper A",
            notes: "Primary upper day",
            isArchived: false
        )
        let coolDownRoutine = WorkoutRoutine(
            name: "Upper Cool-Down",
            notes: "Bring heart rate down",
            isArchived: false
        )
        routine.createdAt = TestSupport.date(2026, 1, 3, 9, 0)
        routine.updatedAt = TestSupport.date(2026, 1, 4, 9, 0)
        routine.warmUpRoutine = warmUpRoutine
        routine.coolDownRoutine = coolDownRoutine
        context.insert(warmUpRoutine)
        context.insert(routine)
        context.insert(coolDownRoutine)

        let warmUpItem = WorkoutRoutineItem(
            order: 0,
            routine: warmUpRoutine,
            exercise: row,
            notes: "Ramp-up rower",
            trackingStyleRaw: ExerciseTrackingStyle.timeOnly.rawValue
        )
        let benchItem = WorkoutRoutineItem(
            order: 0,
            routine: routine,
            exercise: bench,
            notes: "Main lift",
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue,
            segmentRaw: WorkoutExerciseSegment.main.rawValue
        )
        let rowItem = WorkoutRoutineItem(
            order: 1,
            routine: routine,
            exercise: row,
            notes: "Back work",
            trackingStyleRaw: ExerciseTrackingStyle.strength.rawValue,
            segmentRaw: WorkoutExerciseSegment.main.rawValue
        )
        let coolDownItem = WorkoutRoutineItem(
            order: 0,
            routine: coolDownRoutine,
            exercise: row,
            notes: "Easy recovery walk",
            trackingStyleRaw: ExerciseTrackingStyle.timeDistance.rawValue
        )

        context.insert(warmUpItem)
        context.insert(benchItem)
        context.insert(rowItem)
        context.insert(coolDownItem)
        warmUpRoutine.items = [warmUpItem]
        routine.items = [benchItem, rowItem]
        coolDownRoutine.items = [coolDownItem]

        let warmUpPlan0 = WorkoutSetPlan(
            order: 0,
            targetReps: nil,
            targetWeight: nil,
            weightUnit: .kg,
            targetDurationSeconds: 10 * 60,
            targetDistance: nil,
            targetRPE: nil,
            restSeconds: nil,
            routineItem: warmUpItem
        )
        let benchPlan0 = WorkoutSetPlan(
            order: 0,
            targetReps: 5,
            targetWeight: 100,
            weightUnit: .kg,
            targetRPE: 8,
            restSeconds: 180,
            routineItem: benchItem
        )
        let benchPlan1 = WorkoutSetPlan(
            order: 1,
            targetReps: 5,
            targetWeight: 100,
            weightUnit: .kg,
            targetRPE: 8.5,
            restSeconds: 180,
            routineItem: benchItem
        )
        let rowPlan0 = WorkoutSetPlan(
            order: 0,
            targetReps: 10,
            targetWeight: 32.5,
            weightUnit: .kg,
            targetRPE: 7.5,
            restSeconds: 120,
            routineItem: rowItem
        )
        let coolDownPlan0 = WorkoutSetPlan(
            order: 0,
            targetReps: nil,
            targetWeight: nil,
            weightUnit: .kg,
            targetDurationSeconds: 8 * 60,
            targetDistance: 0.8,
            targetRPE: nil,
            restSeconds: nil,
            routineItem: coolDownItem
        )

        context.insert(warmUpPlan0)
        context.insert(benchPlan0)
        context.insert(benchPlan1)
        context.insert(rowPlan0)
        context.insert(coolDownPlan0)

        warmUpItem.setPlans = [warmUpPlan0]
        benchItem.setPlans = [benchPlan0, benchPlan1]
        rowItem.setPlans = [rowPlan0]
        coolDownItem.setPlans = [coolDownPlan0]

        // Seed session
        let session = WorkoutSession(
            startedAt: startedAt,
            sourceRoutineId: routine.id,
            sourceRoutineNameSnapshot: routine.name,
            linkedActivityId: nil
        )
        session.endedAt = finishedAt
        session.status = .completed
        session.reflectionNote = "Strong day"
        context.insert(session)

        let warmUpSessionExercise = WorkoutSessionExercise(
            order: 0,
            exerciseId: row.id,
            exerciseNameSnapshot: row.name,
            notes: "Easy primer",
            trackingStyle: .timeOnly,
            segment: .warmUp,
            session: session
        )
        let benchSessionExercise = WorkoutSessionExercise(
            order: 1,
            exerciseId: bench.id,
            exerciseNameSnapshot: bench.name,
            notes: "Top sets felt good",
            trackingStyle: .strength,
            segment: .main,
            session: session
        )
        let rowSessionExercise = WorkoutSessionExercise(
            order: 2,
            exerciseId: row.id,
            exerciseNameSnapshot: row.name,
            notes: "Hold peak contraction",
            trackingStyle: .strength,
            segment: .main,
            session: session
        )
        let coolDownSessionExercise = WorkoutSessionExercise(
            order: 3,
            exerciseId: row.id,
            exerciseNameSnapshot: row.name,
            notes: "Recovery walk",
            trackingStyle: .timeDistance,
            segment: .coolDown,
            session: session
        )

        context.insert(warmUpSessionExercise)
        context.insert(benchSessionExercise)
        context.insert(rowSessionExercise)
        context.insert(coolDownSessionExercise)
        session.exercises = [warmUpSessionExercise, benchSessionExercise, rowSessionExercise, coolDownSessionExercise]

        let warmUpLog0 = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: nil,
            weight: nil,
            weightUnit: .kg,
            rpe: nil,
            completed: true,
            completedAt: startedAt.addingTimeInterval(4 * 60),
            targetReps: nil,
            targetWeight: nil,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: nil,
            sessionExercise: warmUpSessionExercise
        )
        warmUpLog0.targetDurationSeconds = 10 * 60
        warmUpLog0.actualDurationSeconds = 10 * 60

        let benchLog0 = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: 5,
            weight: 100,
            weightUnit: .kg,
            rpe: 8,
            completed: true,
            completedAt: startedAt.addingTimeInterval(8 * 60),
            targetReps: 5,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRPE: 8,
            targetRestSeconds: 180,
            sessionExercise: benchSessionExercise
        )
        let benchLog1 = WorkoutSetLog(
            order: 1,
            origin: .planned,
            reps: 5,
            weight: 102.5,
            weightUnit: .kg,
            rpe: 8.5,
            completed: true,
            completedAt: startedAt.addingTimeInterval(14 * 60),
            targetReps: 5,
            targetWeight: 100,
            targetWeightUnit: .kg,
            targetRPE: 8.5,
            targetRestSeconds: 180,
            sessionExercise: benchSessionExercise
        )
        let rowLog0 = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: 10,
            weight: 32.5,
            weightUnit: .kg,
            rpe: 7.5,
            completed: true,
            completedAt: startedAt.addingTimeInterval(24 * 60),
            targetReps: 10,
            targetWeight: 32.5,
            targetWeightUnit: .kg,
            targetRPE: 7.5,
            targetRestSeconds: 120,
            sessionExercise: rowSessionExercise
        )
        let coolDownLog0 = WorkoutSetLog(
            order: 0,
            origin: .planned,
            reps: nil,
            weight: nil,
            weightUnit: .kg,
            rpe: nil,
            completed: true,
            completedAt: startedAt.addingTimeInterval(34 * 60),
            targetReps: nil,
            targetWeight: nil,
            targetWeightUnit: .kg,
            targetRPE: nil,
            targetRestSeconds: nil,
            sessionExercise: coolDownSessionExercise
        )
        coolDownLog0.targetDurationSeconds = 8 * 60
        coolDownLog0.actualDurationSeconds = 8 * 60
        coolDownLog0.targetDistance = 0.8
        coolDownLog0.actualDistance = 0.8

        context.insert(warmUpLog0)
        context.insert(benchLog0)
        context.insert(benchLog1)
        context.insert(rowLog0)
        context.insert(coolDownLog0)

        warmUpSessionExercise.setLogs = [warmUpLog0]
        benchSessionExercise.setLogs = [benchLog0, benchLog1]
        rowSessionExercise.setLogs = [rowLog0]
        coolDownSessionExercise.setLogs = [coolDownLog0]

        try context.save()

        // Export
        let exported = try service.exportJSON(
            context: context,
            types: fullWorkoutBackupTypes(),
            preferences: nil,
            prettyPrinted: false
        )

        // Wipe current store to simulate clean reinstall / empty state.
        try wipeWorkoutGraph(from: context)

        XCTAssertEqual(try fetchAll(Exercise.self, from: context).count, 0)
        XCTAssertEqual(try fetchAll(WorkoutRoutine.self, from: context).count, 0)
        XCTAssertEqual(try fetchAll(WorkoutSession.self, from: context).count, 0)

        // Restore
        try service.restoreWorkoutData(exported, context: context)

        // Assert exercises
        let restoredExercises = try fetchAll(Exercise.self, from: context).sorted { $0.name < $1.name }
        XCTAssertEqual(restoredExercises.map(\.name), ["Bench Press", "Chest Supported Row"])

        let restoredBench = try XCTUnwrap(restoredExercises.first(where: { $0.name == "Bench Press" }))
        XCTAssertEqual(restoredBench.instructions, "Pause on chest")
        XCTAssertEqual(restoredBench.notes, "Competition grip")
        XCTAssertEqual(restoredBench.equipmentTagsRaw, "barbell,bench")

        // Assert routine and items
        let restoredRoutines = try fetchAll(WorkoutRoutine.self, from: context)
        XCTAssertEqual(restoredRoutines.count, 3)

        let restoredRoutine = try XCTUnwrap(restoredRoutines.first(where: { $0.name == "Upper A" }))
        let restoredWarmUpRoutine = try XCTUnwrap(restoredRoutines.first(where: { $0.name == "Upper Warm-Up" }))
        let restoredCoolDownRoutine = try XCTUnwrap(restoredRoutines.first(where: { $0.name == "Upper Cool-Down" }))
        XCTAssertEqual(restoredRoutine.name, "Upper A")
        XCTAssertEqual(restoredRoutine.notes, "Primary upper day")
        XCTAssertEqual(restoredRoutine.warmUpRoutine?.id, restoredWarmUpRoutine.id)
        XCTAssertEqual(restoredRoutine.coolDownRoutine?.id, restoredCoolDownRoutine.id)
        let restoredRoutineItems = restoredRoutine.items.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        XCTAssertEqual(restoredRoutineItems.count, 2)
        XCTAssertEqual(restoredRoutineItems.map(\.order), [0, 1])
        XCTAssertEqual(restoredRoutineItems.compactMap { $0.exercise?.name }, ["Bench Press", "Chest Supported Row"])

        let restoredBenchItem = try XCTUnwrap(restoredRoutineItems.first(where: { $0.order == 0 }))
        XCTAssertEqual(restoredBenchItem.notes, "Main lift")
        XCTAssertEqual(restoredBenchItem.segment, .main)

        let restoredBenchPlans = restoredBenchItem.setPlans.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        XCTAssertEqual(restoredBenchPlans.count, 2)
        XCTAssertEqual(restoredBenchPlans.map(\.order), [0, 1])
        XCTAssertEqual(restoredBenchPlans[0].targetReps, 5)
        XCTAssertEqual(restoredBenchPlans[0].targetWeight, 100)
        XCTAssertEqual(restoredBenchPlans[0].restSeconds, 180)

        let restoredRowItem = try XCTUnwrap(restoredRoutineItems.first(where: { $0.order == 1 }))
        XCTAssertEqual(restoredRowItem.notes, "Back work")
        XCTAssertEqual(restoredRowItem.segment, .main)

        let restoredRowPlans = restoredRowItem.setPlans.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        XCTAssertEqual(restoredRowPlans.count, 1)
        XCTAssertEqual(restoredRowPlans[0].targetReps, 10)
        XCTAssertEqual(restoredRowPlans[0].targetWeight, 32.5)

        // Assert session and nested logging graph
        let restoredSessions = try fetchAll(WorkoutSession.self, from: context)
        XCTAssertEqual(restoredSessions.count, 1)

        let restoredSession = try XCTUnwrap(restoredSessions.first)
        XCTAssertEqual(restoredSession.sourceRoutineId, routine.id)
        XCTAssertEqual(restoredSession.sourceRoutineNameSnapshot, "Upper A")
        XCTAssertEqual(restoredSession.status, .completed)
        XCTAssertEqual(restoredSession.reflectionNote, "Strong day")
        let restoredSessionExercises = restoredSession.exercises.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        XCTAssertEqual(restoredSessionExercises.count, 4)
        XCTAssertEqual(restoredSessionExercises.map(\.order), [0, 1, 2, 3])
        XCTAssertEqual(restoredSessionExercises.map(\.segment), [.warmUp, .main, .main, .coolDown])
        XCTAssertEqual(restoredSessionExercises.map(\.exerciseNameSnapshot), ["Chest Supported Row", "Bench Press", "Chest Supported Row", "Chest Supported Row"])

        let restoredWarmUpSessionExercise = try XCTUnwrap(restoredSessionExercises.first(where: { $0.order == 0 }))
        XCTAssertEqual(restoredWarmUpSessionExercise.segment, .warmUp)
        XCTAssertEqual(restoredWarmUpSessionExercise.segmentRaw, WorkoutExerciseSegment.warmUp.rawValue)

        let restoredBenchSessionExercise = try XCTUnwrap(restoredSessionExercises.first(where: { $0.order == 1 }))
        XCTAssertEqual(restoredBenchSessionExercise.exerciseId, bench.id)
        XCTAssertEqual(restoredBenchSessionExercise.notes, "Top sets felt good")
        XCTAssertEqual(restoredBenchSessionExercise.segment, .main)

        let restoredBenchLogs = restoredBenchSessionExercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        XCTAssertEqual(restoredBenchLogs.count, 2)
        XCTAssertEqual(restoredBenchLogs.map(\.order), [0, 1])
        XCTAssertEqual(restoredBenchLogs[0].reps, 5)
        XCTAssertEqual(restoredBenchLogs[0].weight, 100)
        XCTAssertEqual(restoredBenchLogs[0].targetReps, 5)
        XCTAssertEqual(restoredBenchLogs[0].targetWeight, 100)
        XCTAssertTrue(restoredBenchLogs[0].completed)

        let restoredRowSessionExercise = try XCTUnwrap(restoredSessionExercises.first(where: { $0.order == 2 }))
        XCTAssertEqual(restoredRowSessionExercise.exerciseId, row.id)
        XCTAssertEqual(restoredRowSessionExercise.segment, .main)

        let restoredRowLogs = restoredRowSessionExercise.setLogs.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        XCTAssertEqual(restoredRowLogs.count, 1)
        XCTAssertEqual(restoredRowLogs[0].reps, 10)
        XCTAssertEqual(restoredRowLogs[0].weight, 32.5)
        XCTAssertEqual(restoredRowLogs[0].targetRestSeconds, 120)

        let restoredCoolDownSessionExercise = try XCTUnwrap(restoredSessionExercises.first(where: { $0.order == 3 }))
        XCTAssertEqual(restoredCoolDownSessionExercise.segment, .coolDown)
        XCTAssertEqual(restoredCoolDownSessionExercise.segmentRaw, WorkoutExerciseSegment.coolDown.rawValue)
        XCTAssertEqual(restoredCoolDownSessionExercise.setLogs.first?.targetDistance, 0.8)
    }
}
