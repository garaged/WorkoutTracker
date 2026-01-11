import SwiftData
import Foundation

@Model
final class TemplateActivity {
    @Attribute(.unique) var id: UUID
    var title: String

    /// Minutes since start-of-day (local calendar)
    var defaultStartMinute: Int
    var defaultDurationMinutes: Int

    var isEnabled: Bool

    @Attribute(.externalStorage) var recurrenceData: Data

    // --- Kind / workout linkage ---
    /// Stored as raw string for stability/migrations.
    var kindRaw: String = ActivityKind.generic.rawValue

    /// If kind == .workout, links to a reusable routine definition (created later).
    var workoutRoutineId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        defaultStartMinute: Int,
        defaultDurationMinutes: Int,
        isEnabled: Bool = true,
        recurrence: RecurrenceRule,
        kind: ActivityKind = .generic,
        workoutRoutineId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.defaultStartMinute = defaultStartMinute
        self.defaultDurationMinutes = defaultDurationMinutes
        self.isEnabled = isEnabled
        self.recurrenceData = (try? JSONEncoder().encode(recurrence)) ?? Data()

        self.kindRaw = kind.rawValue
        self.workoutRoutineId = workoutRoutineId
    }

    var recurrence: RecurrenceRule {
        get { (try? JSONDecoder().decode(RecurrenceRule.self, from: recurrenceData)) ?? RecurrenceRule(kind: .none) }
        set { recurrenceData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var kind: ActivityKind {
        get { ActivityKind(rawValue: kindRaw) ?? .generic }
        set { kindRaw = newValue.rawValue }
    }

    var isWorkout: Bool { kind == .workout }
}
