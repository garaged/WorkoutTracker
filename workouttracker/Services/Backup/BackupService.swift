// workouttracker/Services/Backup/BackupService.swift
import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class BackupService {

    // MARK: - Public types

    /// Register which SwiftData model types to export.
    struct AnyBackupType {
        let typeName: String
        let fetch: (ModelContext) throws -> [any PersistentModel]

        init<T: PersistentModel>(_ type: T.Type, name: String? = nil) {
            self.typeName = name ?? String(describing: T.self)
            self.fetch = { context in
                let items = try context.fetch(FetchDescriptor<T>())
                return items.map { $0 as any PersistentModel }
            }
        }
    }

    struct Validation: Hashable {
        struct EntityCount: Hashable {
            let type: String
            let count: Int
        }

        let schemaVersion: Int
        let createdAt: Date
        let appVersion: String?
        let appBuild: String?
        let deviceName: String?
        let systemVersion: String?
        let hasPreferencesSnapshot: Bool
        let entityCountsByType: [EntityCount]
        let totalEntities: Int
    }

    enum RestoreError: LocalizedError {
        case unsupportedSchema(found: Int)
        case missingPreferencesSnapshot
        case invalidUUID(type: String, id: String)
        case invalidEntityShape(type: String, id: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let found):
                return "Unsupported backup schema v\(found)."
            case .missingPreferencesSnapshot:
                return "This backup file does not contain a preferences snapshot."
            case .invalidUUID(let type, let id):
                return "Backup entity \(type) has an invalid UUID id: \(id)."
            case .invalidEntityShape(let type, let id, let reason):
                return "Backup entity \(type) (\(id)) is invalid: \(reason)."
            }
        }
    }

    // MARK: - Schema

    /// Bump when you change file structure in incompatible ways.
    ///
    /// v3 adds explicit Data support in JSON export/restore so models like
    /// TemplateActivity can round-trip reliably instead of falling back to
    /// String(describing: Data).
    /// v4 adds routine/session exercise segment persistence so analytics can
    /// distinguish warm-up, main, and cool-down work after restore.
    /// v5 adds first-class tracked activity sessions so the broader activity
    /// domain can round-trip alongside strength workouts.
    private let schemaVersion = 5

    struct BackupFile: Codable {
        let schemaVersion: Int
        let createdAtISO8601: String

        /// Optional so older files can still decode.
        let metadata: Metadata?
        let preferences: PreferencesSnapshot?

        let entities: [Entity]
    }

    struct Metadata: Codable {
        let bundleID: String?
        let appVersion: String?
        let appBuild: String?

        let deviceName: String?
        let systemName: String?
        let systemVersion: String?
        let deviceModel: String?
    }

    struct PreferencesSnapshot: Codable {
        let weightUnitRaw: String?
        let distanceUnitRaw: String?
        let defaultRestSeconds: Int?
        let hapticsEnabled: Bool?
        let autoStartRest: Bool?
        let confirmDestructiveActions: Bool?
        let autoSaveCompletedTrackedActivitiesToAppleHealth: Bool?
    }

    struct Entity: Codable {
        let type: String
        let id: String
        let attributes: [String: JSONValue]
    }

    /// JSON-safe value container.
    enum JSONValue: Codable, Hashable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .null; return }
            if let b = try? c.decode(Bool.self) { self = .bool(b); return }
            if let n = try? c.decode(Double.self) { self = .number(n); return }
            if let s = try? c.decode(String.self) { self = .string(s); return }
            if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
            if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch self {
            case .null: try c.encodeNil()
            case .bool(let v): try c.encode(v)
            case .number(let v): try c.encode(v)
            case .string(let v): try c.encode(v)
            case .array(let v): try c.encode(v)
            case .object(let v): try c.encode(v)
            }
        }
    }

    // MARK: - Export

    func exportJSON(
        context: ModelContext,
        types: [AnyBackupType],
        preferences: UserPreferences? = nil,
        prettyPrinted: Bool = true
    ) throws -> Data {
        let file = try exportBackupFile(context: context, types: types, preferences: preferences)

        let enc = JSONEncoder()
        if prettyPrinted {
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try enc.encode(file)
    }

    func exportBackupFile(
        context: ModelContext,
        types: [AnyBackupType],
        preferences: UserPreferences? = nil
    ) throws -> BackupFile {
        var entities: [Entity] = []

        for t in types {
            let models = try t.fetch(context)
            for m in models {
                let attrs = typedAttributesDictionary(for: m)
                let id = stableID(for: m, attributes: attrs)
                entities.append(Entity(type: t.typeName, id: id, attributes: attrs))
            }
        }

        entities.sort {
            if $0.type != $1.type { return $0.type < $1.type }
            return $0.id < $1.id
        }

        let meta = makeMetadata()
        let prefs = preferences.map { snapPreferences($0) }

        return BackupFile(
            schemaVersion: schemaVersion,
            createdAtISO8601: Self.iso8601.string(from: Date()),
            metadata: meta,
            preferences: prefs,
            entities: entities
        )
    }

    // MARK: - Validate

    func validate(_ data: Data) throws -> Validation {
        let dec = JSONDecoder()
        let file = try dec.decode(BackupFile.self, from: data)

        let created = Self.iso8601.date(from: file.createdAtISO8601) ?? Date(timeIntervalSince1970: 0)

        var counts: [String: Int] = [:]
        for e in file.entities {
            counts[e.type, default: 0] += 1
        }

        let sorted: [Validation.EntityCount] = counts.keys.sorted().map {
            Validation.EntityCount(type: $0, count: counts[$0] ?? 0)
        }

        return Validation(
            schemaVersion: file.schemaVersion,
            createdAt: created,
            appVersion: file.metadata?.appVersion,
            appBuild: file.metadata?.appBuild,
            deviceName: file.metadata?.deviceName,
            systemVersion: file.metadata?.systemVersion,
            hasPreferencesSnapshot: file.preferences != nil,
            entityCountsByType: sorted,
            totalEntities: file.entities.count
        )
    }

    // MARK: - Restore

    /// Safe restore: only restores preferences.
    func restorePreferencesOnly(_ data: Data, preferences: UserPreferences = .shared) throws {
        let dec = JSONDecoder()
        let file = try dec.decode(BackupFile.self, from: data)

        if file.schemaVersion > schemaVersion {
            throw RestoreError.unsupportedSchema(found: file.schemaVersion)
        }
        guard let snap = file.preferences else {
            throw RestoreError.missingPreferencesSnapshot
        }

        applyPreferencesSnapshot(snap, to: preferences)
    }

    /// Restores the full user-data graph from JSON.
    ///
    /// Opinionated behavior:
    /// - Treat the backup as a snapshot, not a patch.
    /// - Delete existing backed-up entities first, then recreate from the file.
    ///   This avoids duplicate unique IDs and relationship drift.
    func restoreWorkoutData(_ data: Data, context: ModelContext) throws {
        let dec = JSONDecoder()
        let file = try dec.decode(BackupFile.self, from: data)

        if file.schemaVersion > schemaVersion {
            throw RestoreError.unsupportedSchema(found: file.schemaVersion)
        }

        // 1) Decode entities into lightweight restore records.
        let byType = Dictionary(grouping: file.entities, by: \.type)

        let exercises = try parseExercises(byType["Exercise"] ?? [])
        let routines = try parseWorkoutRoutines(byType["WorkoutRoutine"] ?? [])
        let routineItems = try parseWorkoutRoutineItems(byType["WorkoutRoutineItem"] ?? [])
        let setPlans = try parseWorkoutSetPlans(byType["WorkoutSetPlan"] ?? [])
        let sessions = try parseWorkoutSessions(byType["WorkoutSession"] ?? [])
        let sessionExercises = try parseWorkoutSessionExercises(byType["WorkoutSessionExercise"] ?? [])
        let setLogs = try parseWorkoutSetLogs(byType["WorkoutSetLog"] ?? [])
        let trackedActivitySessions = try parseTrackedActivitySessions(byType["TrackedActivitySession"] ?? [])
        let activities = try parseActivities(byType["Activity"] ?? [])
        let bodyMeasurements = try parseBodyMeasurements(byType["BodyMeasurement"] ?? [])
        let templateActivities = try parseTemplateActivities(byType["TemplateActivity"] ?? [])
        let templateOverrides = try parseTemplateInstanceOverrides(byType["TemplateInstanceOverride"] ?? [])

        // 2) Snapshot-style replace.
        try deleteAllBackedUpEntities(from: context)

        // 3) Recreate independent roots.
        var exerciseByID: [UUID: Exercise] = [:]
        for raw in exercises {
            let model = Exercise(
                id: raw.id,
                name: raw.name,
                modality: ExerciseModality(rawValue: raw.modalityRaw) ?? .strength,
                instructions: raw.instructions,
                notes: raw.notes,
                mediaKind: ExerciseMediaKind(rawValue: raw.mediaKindRaw) ?? .none,
                mediaAssetName: raw.mediaAssetName,
                mediaURLString: raw.mediaURLString,
                equipmentTagsRaw: raw.equipmentTagsRaw,
                isArchived: raw.isArchived
            )
            model.createdAt = raw.createdAt
            model.updatedAt = raw.updatedAt
            context.insert(model)
            exerciseByID[raw.id] = model
        }

        var routineByID: [UUID: WorkoutRoutine] = [:]
        for raw in routines {
            let model = WorkoutRoutine(
                id: raw.id,
                name: raw.name,
                notes: raw.notes,
                isArchived: raw.isArchived
            )
            model.createdAt = raw.createdAt
            model.updatedAt = raw.updatedAt
            context.insert(model)
            routineByID[raw.id] = model
        }

        var sessionByID: [UUID: WorkoutSession] = [:]
        for raw in sessions {
            let model = WorkoutSession(
                id: raw.id,
                startedAt: raw.startedAt,
                sourceRoutineId: raw.sourceRoutineId,
                sourceRoutineNameSnapshot: raw.sourceRoutineNameSnapshot,
                linkedActivityId: raw.linkedActivityId
            )
            model.endedAt = raw.endedAt
            model.statusRaw = raw.statusRaw
            model.isPaused = raw.isPaused
            model.pausedAt = raw.pausedAt
            model.accumulatedPausedSeconds = raw.accumulatedPausedSeconds
            model.reflectionMood = raw.reflectionMood
            model.reflectionNote = raw.reflectionNote
            model.reflectionCreatedAt = raw.reflectionCreatedAt
            context.insert(model)
            sessionByID[raw.id] = model
        }

        for raw in trackedActivitySessions {
            let model = TrackedActivitySession(
                id: raw.id,
                createdAt: raw.createdAt,
                updatedAt: raw.updatedAt,
                startedAt: raw.startedAt,
                endedAt: raw.endedAt,
                activityKind: TrackedActivityKind(rawValue: raw.activityKindRaw) ?? .walking,
                environment: ActivityEnvironment(rawValue: raw.environmentRaw) ?? .unspecified,
                lifecycleState: TrackedActivityLifecycleState(rawValue: raw.lifecycleStateRaw) ?? .planned,
                totals: TrackedActivityTotals(
                    elapsedDuration: raw.elapsedDuration,
                    distanceMeters: raw.distanceMeters,
                    activeEnergyKilocalories: raw.activeEnergyKilocalories,
                    stepCount: raw.stepCount
                ),
                healthKitExportState: HealthKitExportState(rawValue: raw.healthKitExportStateRaw) ?? .notRequested,
                linkedActivityId: raw.linkedActivityId,
                notes: raw.notes,
                healthKitExportAttemptedAt: raw.healthKitExportAttemptedAt,
                healthKitExportSucceededAt: raw.healthKitExportSucceededAt,
                healthKitExportFailureMessage: raw.healthKitExportFailureMessage,
                hasLocalChangesSinceHealthKitExport: raw.hasLocalChangesSinceHealthKitExport
            )
            model.activeIntervalStartedAt = raw.activeIntervalStartedAt
            model.lastResumedAt = raw.lastResumedAt
            model.lastBackgroundedAt = raw.lastBackgroundedAt
            model.dismissedRecoveryPromptAt = raw.dismissedRecoveryPromptAt
            context.insert(model)
        }

        // 4) Recreate dependent workout graph.
        var routineItemByID: [UUID: WorkoutRoutineItem] = [:]
        for raw in routineItems {
            let model = WorkoutRoutineItem(
                id: raw.id,
                order: raw.order,
                routine: raw.routineID.flatMap { routineByID[$0] },
                exercise: raw.exerciseID.flatMap { exerciseByID[$0] },
                notes: raw.notes,
                trackingStyleRaw: raw.trackingStyleRaw,
                segmentRaw: raw.segmentRaw
            )
            context.insert(model)
            routineItemByID[raw.id] = model
        }

        var setPlanByID: [UUID: WorkoutSetPlan] = [:]
        for raw in setPlans {
            let model = WorkoutSetPlan(
                id: raw.id,
                order: raw.order,
                targetReps: raw.targetReps,
                targetWeight: raw.targetWeight,
                weightUnit: WeightUnit(rawValue: raw.weightUnitRaw) ?? .kg,
                targetDurationSeconds: raw.targetDurationSeconds,
                targetDistance: raw.targetDistance,
                targetRPE: raw.targetRPE,
                restSeconds: raw.restSeconds,
                routineItem: raw.routineItemID.flatMap { routineItemByID[$0] }
            )
            context.insert(model)
            setPlanByID[raw.id] = model
        }

        var sessionExerciseByID: [UUID: WorkoutSessionExercise] = [:]
        for raw in sessionExercises {
            let model = WorkoutSessionExercise(
                id: raw.id,
                order: raw.order,
                exerciseId: raw.exerciseId,
                exerciseNameSnapshot: raw.exerciseNameSnapshot,
                notes: raw.notes,
                trackingStyle: ExerciseTrackingStyle(rawValue: raw.trackingStyleRaw) ?? .strength,
                segment: WorkoutExerciseSegment(rawValue: raw.segmentRaw) ?? .main,
                session: raw.sessionID.flatMap { sessionByID[$0] },
                setLogsStorage: []
            )
            model.targetDurationSeconds = raw.targetDurationSeconds
            model.actualDurationSeconds = raw.actualDurationSeconds
            model.targetDistance = raw.targetDistance
            model.actualDistance = raw.actualDistance
            context.insert(model)
            sessionExerciseByID[raw.id] = model
        }

        var setLogByID: [UUID: WorkoutSetLog] = [:]
        for raw in setLogs {
            let model = WorkoutSetLog(
                id: raw.id,
                order: raw.order,
                origin: WorkoutSetOrigin(rawValue: raw.originRaw) ?? .planned,
                reps: raw.reps,
                weight: raw.weight,
                weightUnit: WeightUnit(rawValue: raw.weightUnitRaw) ?? .kg,
                rpe: raw.rpe,
                completed: raw.completed,
                completedAt: raw.completedAt,
                targetReps: raw.targetReps,
                targetWeight: raw.targetWeight,
                targetWeightUnit: WeightUnit(rawValue: raw.targetWeightUnitRaw) ?? .kg,
                targetRPE: raw.targetRPE,
                targetRestSeconds: raw.targetRestSeconds,
                sessionExercise: raw.sessionExerciseID.flatMap { sessionExerciseByID[$0] }
            )
            model.targetDurationSeconds = raw.targetDurationSeconds
            model.actualDurationSeconds = raw.actualDurationSeconds
            model.targetDistance = raw.targetDistance
            model.actualDistance = raw.actualDistance
            context.insert(model)
            setLogByID[raw.id] = model
        }

        // 5) Non-workout user data included in the same backup snapshot.
        for raw in activities {
            let model = Activity(
                title: raw.title,
                startAt: raw.startAt,
                endAt: raw.endAt,
                laneHint: raw.laneHint,
                kind: ActivityKind(rawValue: raw.kindRaw) ?? .generic,
                workoutRoutineId: raw.workoutRoutineId,
                id: raw.id
            )
            model.isAllDay = raw.isAllDay
            model.templateId = raw.templateId
            model.dayKey = raw.dayKey
            model.generatedKey = raw.generatedKey
            model.plannedStartAt = raw.plannedStartAt
            model.plannedEndAt = raw.plannedEndAt
            model.plannedTitle = raw.plannedTitle
            model.workoutSessionId = raw.workoutSessionId
            model.statusRaw = raw.statusRaw
            model.completedAt = raw.completedAt
            context.insert(model)
        }

        for raw in bodyMeasurements {
            let model = BodyMeasurement(
                id: raw.id,
                measuredAt: raw.measuredAt,
                type: BodyMeasurementType(rawValue: raw.typeRaw) ?? .other,
                value: raw.value,
                unit: BodyMeasurementUnit(rawValue: raw.unitRaw) ?? .kg,
                note: raw.note
            )
            context.insert(model)
        }

        for raw in templateActivities {
            let recurrenceData = raw.recurrenceData ?? Data()
            let recurrence = (try? JSONDecoder().decode(RecurrenceRule.self, from: recurrenceData)) ?? RecurrenceRule(kind: .none)
            let model = TemplateActivity(
                id: raw.id,
                title: raw.title,
                defaultStartMinute: raw.defaultStartMinute,
                defaultDurationMinutes: raw.defaultDurationMinutes,
                isEnabled: raw.isEnabled,
                recurrence: recurrence,
                kind: ActivityKind(rawValue: raw.kindRaw) ?? .generic,
                workoutRoutineId: raw.workoutRoutineId
            )
            context.insert(model)
        }

        for raw in templateOverrides {
            let model = TemplateInstanceOverride(
                templateId: raw.templateId,
                dayKey: raw.dayKey,
                action: TemplateOverrideAction(rawValue: raw.actionRaw) ?? .skippedToday
            )
            model.createdAt = raw.createdAt
            context.insert(model)
        }

        // 6) Rebuild explicit parent collections so ordering stays deterministic.
        for (routineID, routine) in routineByID {
            routine.items = routineItems
                .filter { $0.routineID == routineID }
                .sorted { lhs, rhs in lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order }
                .compactMap { routineItemByID[$0.id] }
        }

        for (routineItemID, routineItem) in routineItemByID {
            routineItem.setPlans = setPlans
                .filter { $0.routineItemID == routineItemID }
                .sorted { lhs, rhs in lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order }
                .compactMap { setPlanByID[$0.id] }
        }

        for (sessionID, session) in sessionByID {
            session.exercises = sessionExercises
                .filter { $0.sessionID == sessionID }
                .sorted { lhs, rhs in lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order }
                .compactMap { sessionExerciseByID[$0.id] }
        }

        for (sessionExerciseID, sessionExercise) in sessionExerciseByID {
            let orderedLogs = setLogs
                .filter { $0.sessionExerciseID == sessionExerciseID }
                .sorted { lhs, rhs in lhs.order == rhs.order ? lhs.id.uuidString < rhs.id.uuidString : lhs.order < rhs.order }
                .compactMap { setLogByID[$0.id] }
            sessionExercise.setLogsStorage = orderedLogs
        }

        try context.save()
    }

    // MARK: - Internals

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func makeMetadata() -> Metadata {
        let info = Bundle.main.infoDictionary
        let bundleID = Bundle.main.bundleIdentifier
        let appVersion = info?["CFBundleShortVersionString"] as? String
        let appBuild = info?["CFBundleVersion"] as? String

        #if canImport(UIKit)
        let d = UIDevice.current
        return Metadata(
            bundleID: bundleID,
            appVersion: appVersion,
            appBuild: appBuild,
            deviceName: d.name,
            systemName: d.systemName,
            systemVersion: d.systemVersion,
            deviceModel: d.model
        )
        #else
        return Metadata(
            bundleID: bundleID,
            appVersion: appVersion,
            appBuild: appBuild,
            deviceName: nil,
            systemName: nil,
            systemVersion: nil,
            deviceModel: nil
        )
        #endif
    }

    private func snapPreferences(_ prefs: UserPreferences) -> PreferencesSnapshot {
        PreferencesSnapshot(
            weightUnitRaw: prefs.weightUnit.rawValue,
            distanceUnitRaw: prefs.distanceUnit.rawValue,
            defaultRestSeconds: prefs.defaultRestSeconds,
            hapticsEnabled: prefs.hapticsEnabled,
            autoStartRest: prefs.autoStartRest,
            confirmDestructiveActions: prefs.confirmDestructiveActions,
            autoSaveCompletedTrackedActivitiesToAppleHealth: prefs.autoSaveCompletedTrackedActivitiesToAppleHealth
        )
    }

    private func applyPreferencesSnapshot(_ snap: PreferencesSnapshot, to prefs: UserPreferences) {
        if let raw = snap.weightUnitRaw, let u = WeightUnit(rawValue: raw) {
            prefs.weightUnit = u
        }
        if let raw = snap.distanceUnitRaw, let u = DistanceUnit(rawValue: raw) {
            prefs.distanceUnit = u
        }
        if let v = snap.defaultRestSeconds { prefs.defaultRestSeconds = v }
        if let v = snap.hapticsEnabled { prefs.hapticsEnabled = v }
        if let v = snap.autoStartRest { prefs.autoStartRest = v }
        if let v = snap.confirmDestructiveActions { prefs.confirmDestructiveActions = v }
        if let v = snap.autoSaveCompletedTrackedActivitiesToAppleHealth {
            prefs.autoSaveCompletedTrackedActivitiesToAppleHealth = v
        }
    }

    private func stableID(
        for model: any PersistentModel,
        attributes: [String: JSONValue]
    ) -> String {
        // Prefer the serialized attributes because that path already unwraps values
        // more reliably than Mirror on SwiftData @Model types.
        if let idValue = attributes["id"], let id = stringValue(from: idValue) {
            if let normalized = normalizedUUIDString(from: id) {
                return normalized
            }
            return id
        }

        if let keyValue = attributes["key"], let key = stringValue(from: keyValue) {
            return key
        }

        // Last resort only.
        return String(describing: model.persistentModelID)
    }

    private func attributesDictionary(for model: any PersistentModel) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]

        let mirror = Mirror(reflecting: model)
        for child in mirror.children {
            guard let key = child.label else { continue }
            if key.hasPrefix("_") { continue }
            if key == "persistentModelID" { continue }
            result[key] = toJSONValue(child.value)
        }

        return result
    }
    
    private func typedAttributesDictionary(for model: any PersistentModel) -> [String: JSONValue] {
        if let model = model as? Exercise {
            return [
                "id": .string(model.id.uuidString),
                "name": .string(model.name),
                "modalityRaw": .string(model.modalityRaw),
                "instructions": model.instructions.map(JSONValue.string) ?? .null,
                "notes": model.notes.map(JSONValue.string) ?? .null,
                "mediaKindRaw": .string(model.mediaKindRaw),
                "mediaAssetName": model.mediaAssetName.map(JSONValue.string) ?? .null,
                "mediaURLString": model.mediaURLString.map(JSONValue.string) ?? .null,
                "isArchived": .bool(model.isArchived),
                "createdAt": .string(Self.iso8601.string(from: model.createdAt)),
                "updatedAt": .string(Self.iso8601.string(from: model.updatedAt)),
                "equipmentTagsRaw": .string(model.equipmentTagsRaw)
            ]
        }

        if let model = model as? WorkoutRoutine {
            return [
                "id": .string(model.id.uuidString),
                "name": .string(model.name),
                "notes": model.notes.map(JSONValue.string) ?? .null,
                "isArchived": .bool(model.isArchived),
                "createdAt": .string(Self.iso8601.string(from: model.createdAt)),
                "updatedAt": .string(Self.iso8601.string(from: model.updatedAt))
            ]
        }

        if let model = model as? WorkoutRoutineItem {
            return [
                "id": .string(model.id.uuidString),
                "order": .number(Double(model.order)),
                "notes": model.notes.map(JSONValue.string) ?? .null,
                "trackingStyleRaw": .string(model.trackingStyleRaw),
                "segmentRaw": .string(model.segmentRaw),
                "routine": model.routine.map { routine in
                    .object([
                        "$ref": .string(routine.id.uuidString),
                        "$type": .string(String(describing: type(of: routine)))
                    ])
                } ?? .null,
                "exercise": model.exercise.map { exercise in
                    .object([
                        "$ref": .string(exercise.id.uuidString),
                        "$type": .string(String(describing: type(of: exercise)))
                    ])
                } ?? .null
            ]
        }

        if let model = model as? WorkoutSetPlan {
            return [
                "id": .string(model.id.uuidString),
                "order": .number(Double(model.order)),
                "targetReps": model.targetReps.map { .number(Double($0)) } ?? .null,
                "targetWeight": model.targetWeight.map(JSONValue.number) ?? .null,
                "weightUnitRaw": .string(model.weightUnitRaw),
                "targetDurationSeconds": model.targetDurationSeconds.map { .number(Double($0)) } ?? .null,
                "targetDistance": model.targetDistance.map(JSONValue.number) ?? .null,
                "targetRPE": model.targetRPE.map(JSONValue.number) ?? .null,
                "restSeconds": model.restSeconds.map { .number(Double($0)) } ?? .null,
                "routineItem": model.routineItem.map { item in
                    .object([
                        "$ref": .string(item.id.uuidString),
                        "$type": .string(String(describing: type(of: item)))
                    ])
                } ?? .null
            ]
        }

        if let model = model as? WorkoutSession {
            return [
                "id": .string(model.id.uuidString),
                "startedAt": .string(Self.iso8601.string(from: model.startedAt)),
                "endedAt": model.endedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "sourceRoutineId": model.sourceRoutineId.map { .string($0.uuidString) } ?? .null,
                "sourceRoutineNameSnapshot": model.sourceRoutineNameSnapshot.map(JSONValue.string) ?? .null,
                "linkedActivityId": model.linkedActivityId.map { .string($0.uuidString) } ?? .null,
                "statusRaw": .string(model.statusRaw),
                "isPaused": .bool(model.isPaused),
                "pausedAt": model.pausedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "accumulatedPausedSeconds": .number(Double(model.accumulatedPausedSeconds)),
                "reflectionMood": model.reflectionMood.map { .string($0.rawValue) } ?? .null,
                "reflectionNote": model.reflectionNote.map(JSONValue.string) ?? .null,
                "reflectionCreatedAt": model.reflectionCreatedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null
            ]
        }

        if let model = model as? WorkoutSessionExercise {
            return [
                "id": .string(model.id.uuidString),
                "order": .number(Double(model.order)),
                "exerciseId": .string(model.exerciseId.uuidString),
                "exerciseNameSnapshot": .string(model.exerciseNameSnapshot),
                "notes": model.notes.map(JSONValue.string) ?? .null,
                "trackingStyleRaw": .string(model.trackingStyleRaw),
                "segmentRaw": .string(model.segmentRaw),
                "session": model.session.map { session in
                    .object([
                        "$ref": .string(session.id.uuidString),
                        "$type": .string(String(describing: type(of: session)))
                    ])
                } ?? .null,
                "targetDurationSeconds": model.targetDurationSeconds.map { .number(Double($0)) } ?? .null,
                "actualDurationSeconds": model.actualDurationSeconds.map { .number(Double($0)) } ?? .null,
                "targetDistance": model.targetDistance.map(JSONValue.number) ?? .null,
                "actualDistance": model.actualDistance.map(JSONValue.number) ?? .null
            ]
        }

        if let model = model as? WorkoutSetLog {
            return [
                "id": .string(model.id.uuidString),
                "order": .number(Double(model.order)),
                "originRaw": .string(model.originRaw),
                "reps": model.reps.map { .number(Double($0)) } ?? .null,
                "weight": model.weight.map(JSONValue.number) ?? .null,
                "weightUnitRaw": .string(model.weightUnitRaw),
                "rpe": model.rpe.map(JSONValue.number) ?? .null,
                "completed": .bool(model.completed),
                "completedAt": model.completedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "targetReps": model.targetReps.map { .number(Double($0)) } ?? .null,
                "targetWeight": model.targetWeight.map(JSONValue.number) ?? .null,
                "targetWeightUnitRaw": .string(model.targetWeightUnitRaw),
                "targetRPE": model.targetRPE.map(JSONValue.number) ?? .null,
                "targetRestSeconds": model.targetRestSeconds.map { .number(Double($0)) } ?? .null,
                "targetDurationSeconds": model.targetDurationSeconds.map { .number(Double($0)) } ?? .null,
                "actualDurationSeconds": model.actualDurationSeconds.map { .number(Double($0)) } ?? .null,
                "targetDistance": model.targetDistance.map(JSONValue.number) ?? .null,
                "actualDistance": model.actualDistance.map(JSONValue.number) ?? .null,
                "sessionExercise": model.sessionExercise.map { exercise in
                    .object([
                        "$ref": .string(exercise.id.uuidString),
                        "$type": .string(String(describing: type(of: exercise)))
                    ])
                } ?? .null
            ]
        }

        if let model = model as? TrackedActivitySession {
            return [
                "id": .string(model.id.uuidString),
                "createdAt": .string(Self.iso8601.string(from: model.createdAt)),
                "updatedAt": .string(Self.iso8601.string(from: model.updatedAt)),
                "startedAt": model.startedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "endedAt": model.endedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "activeIntervalStartedAt": model.activeIntervalStartedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "lastResumedAt": model.lastResumedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "lastBackgroundedAt": model.lastBackgroundedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "dismissedRecoveryPromptAt": model.dismissedRecoveryPromptAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "activityKindRaw": .string(model.activityKindRaw),
                "environmentRaw": .string(model.environmentRaw),
                "lifecycleStateRaw": .string(model.lifecycleStateRaw),
                "healthKitExportStateRaw": .string(model.healthKitExportStateRaw),
                "healthKitExportAttemptedAt": model.healthKitExportAttemptedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "healthKitExportSucceededAt": model.healthKitExportSucceededAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "healthKitExportFailureMessage": model.healthKitExportFailureMessage.map(JSONValue.string) ?? .null,
                "hasLocalChangesSinceHealthKitExport": .bool(model.hasLocalChangesSinceHealthKitExport),
                "elapsedDuration": .number(model.elapsedDuration),
                "distanceMeters": model.distanceMeters.map(JSONValue.number) ?? .null,
                "activeEnergyKilocalories": model.activeEnergyKilocalories.map(JSONValue.number) ?? .null,
                "stepCount": model.stepCount.map { .number(Double($0)) } ?? .null,
                "linkedActivityId": model.linkedActivityId.map { .string($0.uuidString) } ?? .null,
                "notes": model.notes.map(JSONValue.string) ?? .null
            ]
        }

        if let model = model as? Activity {
            return [
                "id": .string(model.id.uuidString),
                "title": .string(model.title),
                "startAt": .string(Self.iso8601.string(from: model.startAt)),
                "endAt": model.endAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "isAllDay": .bool(model.isAllDay),
                "laneHint": .number(Double(model.laneHint)),
                "templateId": model.templateId.map { .string($0.uuidString) } ?? .null,
                "dayKey": model.dayKey.map(JSONValue.string) ?? .null,
                "generatedKey": model.generatedKey.map(JSONValue.string) ?? .null,
                "plannedStartAt": model.plannedStartAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "plannedEndAt": model.plannedEndAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null,
                "plannedTitle": model.plannedTitle.map(JSONValue.string) ?? .null,
                "kindRaw": .string(model.kindRaw),
                "workoutRoutineId": model.workoutRoutineId.map { .string($0.uuidString) } ?? .null,
                "workoutSessionId": model.workoutSessionId.map { .string($0.uuidString) } ?? .null,
                "statusRaw": .string(model.statusRaw),
                "completedAt": model.completedAt.map { .string(Self.iso8601.string(from: $0)) } ?? .null
            ]
        }

        if let model = model as? BodyMeasurement {
            return [
                "id": .string(model.id.uuidString),
                "measuredAt": .string(Self.iso8601.string(from: model.measuredAt)),
                "typeRaw": .string(model.typeRaw),
                "value": .number(model.value),
                "unitRaw": .string(model.unitRaw),
                "note": model.note.map(JSONValue.string) ?? .null
            ]
        }

        if let model = model as? TemplateActivity {
            return [
                "id": .string(model.id.uuidString),
                "title": .string(model.title),
                "defaultStartMinute": .number(Double(model.defaultStartMinute)),
                "defaultDurationMinutes": .number(Double(model.defaultDurationMinutes)),
                "isEnabled": .bool(model.isEnabled),
                "recurrenceData": .object([
                    "$data": .string(model.recurrenceData.base64EncodedString())
                ]),
                "kindRaw": .string(model.kindRaw),
                "workoutRoutineId": model.workoutRoutineId.map { .string($0.uuidString) } ?? .null
            ]
        }

        if let model = model as? TemplateInstanceOverride {
            return [
                "key": .string(model.key),
                "templateId": .string(model.templateId.uuidString),
                "dayKey": .string(model.dayKey),
                "actionRaw": .string(model.actionRaw),
                "createdAt": .string(Self.iso8601.string(from: model.createdAt))
            ]
        }

        return attributesDictionary(for: model)
    }

    private func toJSONValue(_ value: Any) -> JSONValue {
        if let unwrapped = unwrapOptional(value) {
            return toJSONValue(unwrapped)
        } else if isOptionalNil(value) {
            return .null
        }

        if let v = value as? String { return .string(v) }
        if let v = value as? Bool { return .bool(v) }
        if let v = value as? Int { return .number(Double(v)) }
        if let v = value as? Double { return .number(v) }
        if let v = value as? Float { return .number(Double(v)) }
        if let v = value as? UUID { return .string(v.uuidString) }
        if let v = value as? Date { return .string(Self.iso8601.string(from: v)) }
        if let v = value as? Data {
            return .object([
                "$data": .string(v.base64EncodedString())
            ])
        }

        if let m = value as? any PersistentModel {
            let refAttributes = typedAttributesDictionary(for: m)
            return .object([
                "$ref": .string(stableID(for: m, attributes: refAttributes)),
                "$type": .string(String(describing: type(of: m)))
            ])
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .collection || mirror.displayStyle == .set {
            let arr = mirror.children.map { toJSONValue($0.value) }
            return .array(arr)
        }

        if mirror.displayStyle == .dictionary {
            var obj: [String: JSONValue] = [:]
            for child in mirror.children {
                let tupleMirror = Mirror(reflecting: child.value)
                let parts = Array(tupleMirror.children)
                if parts.count == 2 {
                    let k = String(describing: parts[0].value)
                    obj[k] = toJSONValue(parts[1].value)
                }
            }
            return .object(obj)
        }

        if mirror.displayStyle == .enum {
            return .string(String(describing: value))
        }

        return .string(String(describing: value))
    }

    private func isOptionalNil(_ value: Any) -> Bool {
        let m = Mirror(reflecting: value)
        return m.displayStyle == .optional && m.children.isEmpty
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        let m = Mirror(reflecting: value)
        guard m.displayStyle == .optional else { return value }
        return m.children.first?.value
    }

    private func deleteAllBackedUpEntities(from context: ModelContext) throws {
        try deleteAll(WorkoutSetLog.self, from: context)
        try deleteAll(WorkoutSessionExercise.self, from: context)
        try deleteAll(WorkoutSession.self, from: context)
        try deleteAll(TrackedActivitySession.self, from: context)
        try deleteAll(WorkoutSetPlan.self, from: context)
        try deleteAll(WorkoutRoutineItem.self, from: context)
        try deleteAll(WorkoutRoutine.self, from: context)
        try deleteAll(Exercise.self, from: context)

        try deleteAll(Activity.self, from: context)
        try deleteAll(BodyMeasurement.self, from: context)
        try deleteAll(TemplateInstanceOverride.self, from: context)
        try deleteAll(TemplateActivity.self, from: context)

        try context.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type, from context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }

    // MARK: - Parsing helpers

    private struct ExerciseRecord {
        let id: UUID
        let name: String
        let modalityRaw: String
        let instructions: String?
        let notes: String?
        let mediaKindRaw: String
        let mediaAssetName: String?
        let mediaURLString: String?
        let isArchived: Bool
        let createdAt: Date
        let updatedAt: Date
        let equipmentTagsRaw: String
    }

    private struct WorkoutRoutineRecord {
        let id: UUID
        let name: String
        let notes: String?
        let isArchived: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    private struct WorkoutRoutineItemRecord {
        let id: UUID
        let order: Int
        let notes: String?
        let routineID: UUID?
        let exerciseID: UUID?
        let trackingStyleRaw: String
        let segmentRaw: String
    }

    private struct WorkoutSetPlanRecord {
        let id: UUID
        let order: Int
        let targetReps: Int?
        let targetWeight: Double?
        let weightUnitRaw: String
        let targetDurationSeconds: Int?
        let targetDistance: Double?
        let targetRPE: Double?
        let restSeconds: Int?
        let routineItemID: UUID?
    }

    private struct WorkoutSessionRecord {
        let id: UUID
        let startedAt: Date
        let endedAt: Date?
        let sourceRoutineId: UUID?
        let sourceRoutineNameSnapshot: String?
        let linkedActivityId: UUID?
        let statusRaw: String
        let isPaused: Bool
        let pausedAt: Date?
        let accumulatedPausedSeconds: Int
        let reflectionMood: SessionReflectionMood?
        let reflectionNote: String?
        let reflectionCreatedAt: Date?
    }

    private struct WorkoutSessionExerciseRecord {
        let id: UUID
        let order: Int
        let exerciseId: UUID
        let exerciseNameSnapshot: String
        let notes: String?
        let trackingStyleRaw: String
        let segmentRaw: String
        let sessionID: UUID?
        let targetDurationSeconds: Int?
        let actualDurationSeconds: Int?
        let targetDistance: Double?
        let actualDistance: Double?
    }

    private struct WorkoutSetLogRecord {
        let id: UUID
        let order: Int
        let originRaw: String
        let reps: Int?
        let weight: Double?
        let weightUnitRaw: String
        let rpe: Double?
        let completed: Bool
        let completedAt: Date?
        let targetReps: Int?
        let targetWeight: Double?
        let targetWeightUnitRaw: String
        let targetRPE: Double?
        let targetRestSeconds: Int?
        let targetDurationSeconds: Int?
        let actualDurationSeconds: Int?
        let targetDistance: Double?
        let actualDistance: Double?
        let sessionExerciseID: UUID?
    }

    private struct TrackedActivitySessionRecord {
        let id: UUID
        let createdAt: Date
        let updatedAt: Date
        let startedAt: Date?
        let endedAt: Date?
        let activeIntervalStartedAt: Date?
        let lastResumedAt: Date?
        let lastBackgroundedAt: Date?
        let dismissedRecoveryPromptAt: Date?
        let activityKindRaw: String
        let environmentRaw: String
        let lifecycleStateRaw: String
        let healthKitExportStateRaw: String
        let healthKitExportAttemptedAt: Date?
        let healthKitExportSucceededAt: Date?
        let healthKitExportFailureMessage: String?
        let hasLocalChangesSinceHealthKitExport: Bool
        let elapsedDuration: Double
        let distanceMeters: Double?
        let activeEnergyKilocalories: Double?
        let stepCount: Int?
        let linkedActivityId: UUID?
        let notes: String?
    }

    private struct ActivityRecord {
        let id: UUID
        let title: String
        let startAt: Date
        let endAt: Date?
        let isAllDay: Bool
        let laneHint: Int
        let templateId: UUID?
        let dayKey: String?
        let generatedKey: String?
        let plannedStartAt: Date?
        let plannedEndAt: Date?
        let plannedTitle: String?
        let kindRaw: String
        let workoutRoutineId: UUID?
        let workoutSessionId: UUID?
        let statusRaw: String
        let completedAt: Date?
    }

    private struct BodyMeasurementRecord {
        let id: UUID
        let measuredAt: Date
        let typeRaw: String
        let value: Double
        let unitRaw: String
        let note: String?
    }

    private struct TemplateActivityRecord {
        let id: UUID
        let title: String
        let defaultStartMinute: Int
        let defaultDurationMinutes: Int
        let isEnabled: Bool
        let recurrenceData: Data?
        let kindRaw: String
        let workoutRoutineId: UUID?
    }

    private struct TemplateInstanceOverrideRecord {
        let key: String
        let templateId: UUID
        let dayKey: String
        let actionRaw: String
        let createdAt: Date
    }

    private func parseExercises(_ entities: [Entity]) throws -> [ExerciseRecord] {
        try entities.map { e in
            let id = try uuidID(for: e)

            let fallbackName =
                string("exerciseNameSnapshot", in: e) ??
                string("title", in: e) ??
                "Recovered Exercise \(id.uuidString.prefix(8))"

            return ExerciseRecord(
                id: id,
                name: string("name", in: e) ?? fallbackName,
                modalityRaw: string("modalityRaw", in: e) ?? ExerciseModality.strength.rawValue,
                instructions: string("instructions", in: e),
                notes: string("notes", in: e),
                mediaKindRaw: string("mediaKindRaw", in: e) ?? ExerciseMediaKind.none.rawValue,
                mediaAssetName: string("mediaAssetName", in: e),
                mediaURLString: string("mediaURLString", in: e),
                isArchived: bool("isArchived", in: e) ?? false,
                createdAt: date("createdAt", in: e) ?? Date(),
                updatedAt: date("updatedAt", in: e) ?? Date(),
                equipmentTagsRaw: string("equipmentTagsRaw", in: e) ?? ""
            )
        }
    }

    private func parseWorkoutRoutines(_ entities: [Entity]) throws -> [WorkoutRoutineRecord] {
        try entities.map { e in
            WorkoutRoutineRecord(
                id: try uuidID(for: e),
                name: try requiredString("name", in: e),
                notes: string("notes", in: e),
                isArchived: bool("isArchived", in: e) ?? false,
                createdAt: date("createdAt", in: e) ?? Date(),
                updatedAt: date("updatedAt", in: e) ?? Date()
            )
        }
    }

    private func parseWorkoutRoutineItems(_ entities: [Entity]) throws -> [WorkoutRoutineItemRecord] {
        try entities.map { e in
            WorkoutRoutineItemRecord(
                id: try uuidID(for: e),
                order: int("order", in: e) ?? 0,
                notes: string("notes", in: e),
                routineID: refUUID("routine", in: e),
                exerciseID: refUUID("exercise", in: e),
                trackingStyleRaw: string("trackingStyleRaw", in: e) ?? ExerciseTrackingStyle.strength.rawValue,
                segmentRaw: string("segmentRaw", in: e) ?? WorkoutExerciseSegment.main.rawValue
            )
        }
    }

    private func parseWorkoutSetPlans(_ entities: [Entity]) throws -> [WorkoutSetPlanRecord] {
        try entities.map { e in
            WorkoutSetPlanRecord(
                id: try uuidID(for: e),
                order: int("order", in: e) ?? 0,
                targetReps: int("targetReps", in: e),
                targetWeight: double("targetWeight", in: e),
                weightUnitRaw: string("weightUnitRaw", in: e) ?? WeightUnit.kg.rawValue,
                targetDurationSeconds: int("targetDurationSeconds", in: e),
                targetDistance: double("targetDistance", in: e),
                targetRPE: double("targetRPE", in: e),
                restSeconds: int("restSeconds", in: e),
                routineItemID: refUUID("routineItem", in: e)
            )
        }
    }

    private func parseWorkoutSessions(_ entities: [Entity]) throws -> [WorkoutSessionRecord] {
        try entities.map { e in
            WorkoutSessionRecord(
                id: try uuidID(for: e),
                startedAt: date("startedAt", in: e) ?? Date(),
                endedAt: date("endedAt", in: e),
                sourceRoutineId: uuid("sourceRoutineId", in: e),
                sourceRoutineNameSnapshot: string("sourceRoutineNameSnapshot", in: e),
                linkedActivityId: uuid("linkedActivityId", in: e),
                statusRaw: string("statusRaw", in: e) ?? WorkoutSessionStatus.inProgress.rawValue,
                isPaused: bool("isPaused", in: e) ?? false,
                pausedAt: date("pausedAt", in: e),
                accumulatedPausedSeconds: int("accumulatedPausedSeconds", in: e) ?? 0,
                reflectionMood: string("reflectionMood", in: e).flatMap(SessionReflectionMood.init(rawValue:)),
                reflectionNote: string("reflectionNote", in: e),
                reflectionCreatedAt: date("reflectionCreatedAt", in: e)
            )
        }
    }

    private func parseWorkoutSessionExercises(_ entities: [Entity]) throws -> [WorkoutSessionExerciseRecord] {
        try entities.map { e in
            WorkoutSessionExerciseRecord(
                id: try uuidID(for: e),
                order: int("order", in: e) ?? 0,
                exerciseId: try requiredUUID("exerciseId", in: e),
                exerciseNameSnapshot: string("exerciseNameSnapshot", in: e) ?? "Exercise",
                notes: string("notes", in: e),
                trackingStyleRaw: string("trackingStyleRaw", in: e) ?? ExerciseTrackingStyle.strength.rawValue,
                segmentRaw: string("segmentRaw", in: e) ?? WorkoutExerciseSegment.main.rawValue,
                sessionID: refUUID("session", in: e),
                targetDurationSeconds: int("targetDurationSeconds", in: e),
                actualDurationSeconds: int("actualDurationSeconds", in: e),
                targetDistance: double("targetDistance", in: e),
                actualDistance: double("actualDistance", in: e)
            )
        }
    }

    private func parseWorkoutSetLogs(_ entities: [Entity]) throws -> [WorkoutSetLogRecord] {
        try entities.map { e in
            WorkoutSetLogRecord(
                id: try uuidID(for: e),
                order: int("order", in: e) ?? 0,
                originRaw: string("originRaw", in: e) ?? WorkoutSetOrigin.planned.rawValue,
                reps: int("reps", in: e),
                weight: double("weight", in: e),
                weightUnitRaw: string("weightUnitRaw", in: e) ?? WeightUnit.kg.rawValue,
                rpe: double("rpe", in: e),
                completed: bool("completed", in: e) ?? false,
                completedAt: date("completedAt", in: e),
                targetReps: int("targetReps", in: e),
                targetWeight: double("targetWeight", in: e),
                targetWeightUnitRaw: string("targetWeightUnitRaw", in: e) ?? WeightUnit.kg.rawValue,
                targetRPE: double("targetRPE", in: e),
                targetRestSeconds: int("targetRestSeconds", in: e),
                targetDurationSeconds: int("targetDurationSeconds", in: e),
                actualDurationSeconds: int("actualDurationSeconds", in: e),
                targetDistance: double("targetDistance", in: e),
                actualDistance: double("actualDistance", in: e),
                sessionExerciseID: refUUID("sessionExercise", in: e)
            )
        }
    }

    private func parseTrackedActivitySessions(_ entities: [Entity]) throws -> [TrackedActivitySessionRecord] {
        try entities.map { e in
            TrackedActivitySessionRecord(
                id: try uuidID(for: e),
                createdAt: date("createdAt", in: e) ?? Date(),
                updatedAt: date("updatedAt", in: e) ?? Date(),
                startedAt: date("startedAt", in: e),
                endedAt: date("endedAt", in: e),
                activeIntervalStartedAt: date("activeIntervalStartedAt", in: e),
                lastResumedAt: date("lastResumedAt", in: e),
                lastBackgroundedAt: date("lastBackgroundedAt", in: e),
                dismissedRecoveryPromptAt: date("dismissedRecoveryPromptAt", in: e),
                activityKindRaw: string("activityKindRaw", in: e) ?? TrackedActivityKind.walking.rawValue,
                environmentRaw: string("environmentRaw", in: e) ?? ActivityEnvironment.unspecified.rawValue,
                lifecycleStateRaw: string("lifecycleStateRaw", in: e) ?? TrackedActivityLifecycleState.planned.rawValue,
                healthKitExportStateRaw: string("healthKitExportStateRaw", in: e) ?? HealthKitExportState.notRequested.rawValue,
                healthKitExportAttemptedAt: date("healthKitExportAttemptedAt", in: e),
                healthKitExportSucceededAt: date("healthKitExportSucceededAt", in: e),
                healthKitExportFailureMessage: string("healthKitExportFailureMessage", in: e),
                hasLocalChangesSinceHealthKitExport: bool("hasLocalChangesSinceHealthKitExport", in: e) ?? false,
                elapsedDuration: double("elapsedDuration", in: e) ?? 0,
                distanceMeters: double("distanceMeters", in: e),
                activeEnergyKilocalories: double("activeEnergyKilocalories", in: e),
                stepCount: int("stepCount", in: e),
                linkedActivityId: uuid("linkedActivityId", in: e),
                notes: string("notes", in: e)
            )
        }
    }

    private func parseActivities(_ entities: [Entity]) throws -> [ActivityRecord] {
        try entities.map { e in
            ActivityRecord(
                id: try uuidID(for: e),
                title: string("title", in: e) ?? "",
                startAt: date("startAt", in: e) ?? Date(),
                endAt: date("endAt", in: e),
                isAllDay: bool("isAllDay", in: e) ?? false,
                laneHint: int("laneHint", in: e) ?? 0,
                templateId: uuid("templateId", in: e),
                dayKey: string("dayKey", in: e),
                generatedKey: string("generatedKey", in: e),
                plannedStartAt: date("plannedStartAt", in: e),
                plannedEndAt: date("plannedEndAt", in: e),
                plannedTitle: string("plannedTitle", in: e),
                kindRaw: string("kindRaw", in: e) ?? ActivityKind.generic.rawValue,
                workoutRoutineId: uuid("workoutRoutineId", in: e),
                workoutSessionId: uuid("workoutSessionId", in: e),
                statusRaw: string("statusRaw", in: e) ?? ActivityStatus.planned.rawValue,
                completedAt: date("completedAt", in: e)
            )
        }
    }

    private func parseBodyMeasurements(_ entities: [Entity]) throws -> [BodyMeasurementRecord] {
        try entities.map { e in
            BodyMeasurementRecord(
                id: try uuidID(for: e),
                measuredAt: date("measuredAt", in: e) ?? Date(),
                typeRaw: string("typeRaw", in: e) ?? BodyMeasurementType.other.rawValue,
                value: double("value", in: e) ?? 0,
                unitRaw: string("unitRaw", in: e) ?? BodyMeasurementUnit.kg.rawValue,
                note: string("note", in: e)
            )
        }
    }

    private func parseTemplateActivities(_ entities: [Entity]) throws -> [TemplateActivityRecord] {
        try entities.map { e in
            TemplateActivityRecord(
                id: try uuidID(for: e),
                title: string("title", in: e) ?? "",
                defaultStartMinute: int("defaultStartMinute", in: e) ?? 0,
                defaultDurationMinutes: int("defaultDurationMinutes", in: e) ?? 0,
                isEnabled: bool("isEnabled", in: e) ?? true,
                recurrenceData: data("recurrenceData", in: e),
                kindRaw: string("kindRaw", in: e) ?? ActivityKind.generic.rawValue,
                workoutRoutineId: uuid("workoutRoutineId", in: e)
            )
        }
    }

    private func parseTemplateInstanceOverrides(_ entities: [Entity]) throws -> [TemplateInstanceOverrideRecord] {
        try entities.map { e in
            guard let key = string("key", in: e) ?? (UUID(uuidString: e.id) == nil ? e.id : nil) else {
                throw RestoreError.invalidEntityShape(type: e.type, id: e.id, reason: "Missing override key")
            }
            guard let templateId = uuid("templateId", in: e) else {
                throw RestoreError.invalidEntityShape(type: e.type, id: e.id, reason: "Missing templateId")
            }
            guard let dayKey = string("dayKey", in: e) else {
                throw RestoreError.invalidEntityShape(type: e.type, id: e.id, reason: "Missing dayKey")
            }
            return TemplateInstanceOverrideRecord(
                key: key,
                templateId: templateId,
                dayKey: dayKey,
                actionRaw: string("actionRaw", in: e) ?? TemplateOverrideAction.skippedToday.rawValue,
                createdAt: date("createdAt", in: e) ?? Date()
            )
        }
    }

    private func uuidID(for entity: Entity) throws -> UUID {
        guard let id = normalizedUUID(from: entity.id) else {
            throw RestoreError.invalidUUID(type: entity.type, id: entity.id)
        }
        return id
    }

    private func uuid(_ key: String, in entity: Entity) -> UUID? {
        guard let raw = string(key, in: entity) else { return nil }
        return normalizedUUID(from: raw)
    }

    private func refUUID(_ key: String, in entity: Entity) -> UUID? {
        guard let value = entity.attributes[key] else { return nil }
        guard case .object(let obj) = value,
              case .string(let raw)? = obj["$ref"] else {
            return nil
        }
        return normalizedUUID(from: raw)
    }
    
    private func requiredString(_ key: String, in entity: Entity) throws -> String {
        if let value = string(key, in: entity), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        throw RestoreError.invalidEntityShape(
            type: entity.type,
            id: entity.id,
            reason: "Missing \(key)"
        )
    }
    
    private func requiredUUID(_ key: String, in entity: Entity) throws -> UUID {
        if let value = uuid(key, in: entity) {
            return value
        }
        throw RestoreError.invalidEntityShape(
            type: entity.type,
            id: entity.id,
            reason: "Missing or invalid \(key)"
        )
    }

    private func string(_ key: String, in entity: Entity) -> String? {
        guard let value = entity.attributes[key] else { return nil }
        switch value {
        case .string(let s):
            return s
        case .number(let n):
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .null, .array, .object:
            return nil
        }
    }

    private func bool(_ key: String, in entity: Entity) -> Bool? {
        guard let value = entity.attributes[key] else { return nil }
        switch value {
        case .bool(let b):
            return b
        case .string(let s):
            return Bool(s)
        case .number(let n):
            return n != 0
        case .null, .array, .object:
            return nil
        }
    }

    private func int(_ key: String, in entity: Entity) -> Int? {
        guard let value = entity.attributes[key] else { return nil }
        switch value {
        case .number(let n):
            return Int(n)
        case .string(let s):
            return Int(s)
        case .bool(let b):
            return b ? 1 : 0
        case .null, .array, .object:
            return nil
        }
    }

    private func double(_ key: String, in entity: Entity) -> Double? {
        guard let value = entity.attributes[key] else { return nil }
        switch value {
        case .number(let n):
            return n
        case .string(let s):
            return Double(s)
        case .bool(let b):
            return b ? 1 : 0
        case .null, .array, .object:
            return nil
        }
    }

    private func date(_ key: String, in entity: Entity) -> Date? {
        guard let raw = string(key, in: entity) else { return nil }
        return Self.iso8601.date(from: raw)
    }
    
    private func data(_ key: String, in entity: Entity) -> Data? {
        guard let value = entity.attributes[key] else { return nil }
        switch value {
        case .object(let obj):
            guard case .string(let base64)? = obj["$data"] else { return nil }
            return Data(base64Encoded: base64)
        case .string(let s):
            // Backward-compatible best effort for any future/plain-string encoding.
            return Data(base64Encoded: s)
        default:
            return nil
        }
    }
    
    private func stringValue(from value: JSONValue) -> String? {
        if case .string(let s) = value {
            return s
        }
        return nil
    }

    private func normalizedUUIDString(from raw: String) -> String? {
        if let uuid = normalizedUUID(from: raw) {
            return uuid.uuidString.uppercased()
        }
        return nil
    }

    private func normalizedUUID(from raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let uuid = UUID(uuidString: trimmed) {
            return uuid
        }

        // Backward compatibility:
        // extract UUID embedded inside a SwiftData PersistentIdentifier string.
        let pattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let matchRange = Range(match.range, in: trimmed) else {
            return nil
        }

        let candidate = String(trimmed[matchRange])
        return UUID(uuidString: candidate)
    }
}
