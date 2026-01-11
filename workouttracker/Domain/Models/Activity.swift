import Foundation
import SwiftData

enum ActivityStatus: String, Codable {
    case planned
    case done
    case skipped
}

@Model
final class Activity {
    var title: String
    var startAt: Date
    var endAt: Date?
    var isAllDay: Bool = false

    // ✅ Persisted “preferred lane/column” for timeline layout
    var laneHint: Int

    // --- Template linkage (optional) ---
    var templateId: UUID?

    /// "YYYY-MM-DD" day bucket (lets you fetch today's activities cheaply & reliably)
    var dayKey: String?

    /// "\(templateId)|\(dayKey)" for generated instances (idempotency key)
    @Attribute(.unique) var generatedKey: String?

    // --- Planned vs actual ---
    var plannedStartAt: Date?
    var plannedEndAt: Date?
    var plannedTitle: String?


    // --- Completion / state ---
    var statusRaw: String
    var completedAt: Date?

    init(title: String, startAt: Date, endAt: Date? = nil, laneHint: Int = 0) {
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.laneHint = laneHint

        self.templateId = nil
        self.dayKey = nil
        self.generatedKey = nil

        self.plannedStartAt = nil
        self.plannedEndAt = nil
        self.plannedTitle = nil


        self.statusRaw = ActivityStatus.planned.rawValue
        self.completedAt = nil
    }

    var status: ActivityStatus {
        get { ActivityStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var isDone: Bool { status == .done }
}

