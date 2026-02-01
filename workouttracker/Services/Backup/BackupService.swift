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
        case notImplementedYetWorkoutData

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let found):
                return "Unsupported backup schema v\(found)."
            case .missingPreferencesSnapshot:
                return "This backup file does not contain a preferences snapshot."
            case .notImplementedYetWorkoutData:
                return "Workout data restore is intentionally not enabled yet. Export is safe; restore requires per-model mapping to avoid corrupting data."
            }
        }
    }

    // MARK: - Schema

    /// Bump when you change file structure in incompatible ways.
    private let schemaVersion = 2

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
        let defaultRestSeconds: Int?
        let hapticsEnabled: Bool?
        let autoStartRest: Bool?
        let confirmDestructiveActions: Bool?
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
                let id = stableID(for: m)
                let attrs = attributesDictionary(for: m)
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

    // MARK: - Restore (type-safe: preferences only for now)

    /// Safe restore: only restores preferences. Does NOT touch SwiftData entities.
    func restorePreferencesOnly(_ data: Data, preferences: UserPreferences = .shared) throws {
        let dec = JSONDecoder()
        let file = try dec.decode(BackupFile.self, from: data)

        // Future-proof guardrails:
        if file.schemaVersion > schemaVersion {
            throw RestoreError.unsupportedSchema(found: file.schemaVersion)
        }
        guard let snap = file.preferences else {
            throw RestoreError.missingPreferencesSnapshot
        }

        applyPreferencesSnapshot(snap, to: preferences)
    }

    /// Not enabled yet (intentionally).
    func restoreWorkoutData(_ data: Data, context: ModelContext) throws {
        throw RestoreError.notImplementedYetWorkoutData
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
            defaultRestSeconds: prefs.defaultRestSeconds,
            hapticsEnabled: prefs.hapticsEnabled,
            autoStartRest: prefs.autoStartRest,
            confirmDestructiveActions: prefs.confirmDestructiveActions
        )
    }

    private func applyPreferencesSnapshot(_ snap: PreferencesSnapshot, to prefs: UserPreferences) {
        if let raw = snap.weightUnitRaw, let u = WeightUnit(rawValue: raw) {
            prefs.weightUnit = u
        }
        if let v = snap.defaultRestSeconds { prefs.defaultRestSeconds = v }
        if let v = snap.hapticsEnabled { prefs.hapticsEnabled = v }
        if let v = snap.autoStartRest { prefs.autoStartRest = v }
        if let v = snap.confirmDestructiveActions { prefs.confirmDestructiveActions = v }
    }

    private func stableID(for model: any PersistentModel) -> String {
        if let uuid = readUUIDProperty(named: "id", from: model) {
            return uuid.uuidString
        }
        return String(describing: model.persistentModelID)
    }

    private func readUUIDProperty(named name: String, from model: Any) -> UUID? {
        let mirror = Mirror(reflecting: model)
        for child in mirror.children {
            guard child.label == name else { continue }
            return child.value as? UUID
        }
        return nil
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

        if let m = value as? any PersistentModel {
            return .object([
                "$ref": .string(stableID(for: m)),
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
}
