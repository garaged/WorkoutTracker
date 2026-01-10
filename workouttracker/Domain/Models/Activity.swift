import Foundation
import SwiftData

@Model
final class Activity {
    var title: String
    var startAt: Date
    var endAt: Date?

    // ✅ Persisted “preferred lane/column” for timeline layout
    var laneHint: Int

    init(title: String, startAt: Date, endAt: Date? = nil, laneHint: Int = 0) {
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.laneHint = laneHint
    }
}
