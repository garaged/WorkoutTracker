import SwiftData
import Foundation

enum TemplateOverrideAction: String, Codable {
    case skippedToday
    case deletedToday
}

@Model
final class TemplateInstanceOverride {
    @Attribute(.unique) var key: String  // "\(templateId)|\(dayKey)"
    var templateId: UUID
    var dayKey: String
    var actionRaw: String
    var createdAt: Date

    init(templateId: UUID, dayKey: String, action: TemplateOverrideAction) {
        self.templateId = templateId
        self.dayKey = dayKey
        self.key = "\(templateId.uuidString)|\(dayKey)"
        self.actionRaw = action.rawValue
        self.createdAt = Date()
    }

    var action: TemplateOverrideAction {
        get { TemplateOverrideAction(rawValue: actionRaw) ?? .skippedToday }
        set { actionRaw = newValue.rawValue }
    }
}
