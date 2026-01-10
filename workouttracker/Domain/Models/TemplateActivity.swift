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

    init(
        id: UUID = UUID(),
        title: String,
        defaultStartMinute: Int,
        defaultDurationMinutes: Int,
        isEnabled: Bool = true,
        recurrence: RecurrenceRule
    ) {
        self.id = id
        self.title = title
        self.defaultStartMinute = defaultStartMinute
        self.defaultDurationMinutes = defaultDurationMinutes
        self.isEnabled = isEnabled
        self.recurrenceData = (try? JSONEncoder().encode(recurrence)) ?? Data()
    }

    var recurrence: RecurrenceRule {
        get { (try? JSONDecoder().decode(RecurrenceRule.self, from: recurrenceData)) ?? RecurrenceRule(kind: .none) }
        set { recurrenceData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
