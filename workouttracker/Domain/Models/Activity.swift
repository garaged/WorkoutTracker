import Foundation
import SwiftData

@Model
final class Activity {
    var title: String
    var startAt: Date
    var endAt: Date?

    init(title: String, startAt: Date, endAt: Date? = nil) {
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
    }
}
