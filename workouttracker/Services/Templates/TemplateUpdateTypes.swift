import Foundation

// MARK: - UI scope

enum UpdateScope: String, CaseIterable, Identifiable {
    case thisInstance = "This instance"
    case thisAndFuture = "This & future"
    case allInstances = "All instances"

    var id: String { rawValue }
}

// MARK: - Draft (lets UI preview without mutating the stored TemplateActivity)

struct TemplateDraft: Equatable {
    let id: UUID
    let title: String
    let isEnabled: Bool
    let defaultStartMinute: Int
    let defaultDurationMinutes: Int
    let recurrence: RecurrenceRule
    let kind: ActivityKind
    let workoutRoutineId: UUID?
}

// MARK: - Preview / plan

struct TemplateUpdatePreview: Equatable {
    let affectedCount: Int
    let sampleStartDates: [Date]
}

struct TemplateUpdatePlan {
    let templateId: UUID
    let scope: UpdateScope
    let applyDay: Date

    /// Existing activities that will be mutated
    let updates: [PlannedActivityUpdate]

    /// New activities that will be created (typically only for applyDay)
    let creates: [PlannedActivityCreate]

    /// Override keys to delete (executed last)
    let overrideKeysToDelete: [String]

    /// Rollback snapshots for existing activities
    let beforeSnapshots: [UUID: ActivitySnapshot]

    /// For rollback of created rows
    let createdGeneratedKeys: [String]

    let preview: TemplateUpdatePreview

    var affectedCount: Int { updates.count + creates.count }
}

// MARK: - Planned mutations

struct PlannedActivityUpdate {
    let activityId: UUID
    let after: ActivitySnapshot
}

struct PlannedActivityCreate {
    let generatedKey: String
    let dayKey: String
    let title: String
    let startAt: Date
    let endAt: Date?
    let kind: ActivityKind
    let workoutRoutineId: UUID?

    let templateId: UUID

    let plannedTitle: String
    let plannedStartAt: Date
    let plannedEndAt: Date?
}

// MARK: - Snapshot (only includes fields we care about for equality + rollback)

struct ActivitySnapshot: Equatable {
    let title: String
    let startAt: Date
    let endAt: Date?

    let templateId: UUID?
    let dayKey: String?
    let generatedKey: String?

    let plannedTitle: String?
    let plannedStartAt: Date?
    let plannedEndAt: Date?

    let kind: ActivityKind
    let workoutRoutineId: UUID?
    let workoutSessionId: UUID?
    let status: ActivityStatus
}

// MARK: - Errors

enum TemplateUpdateError: Error, LocalizedError {
    case missingActivity(UUID)

    var errorDescription: String? {
        switch self {
        case .missingActivity(let id):
            return "Could not fetch activity \(id)."
        }
    }
}
