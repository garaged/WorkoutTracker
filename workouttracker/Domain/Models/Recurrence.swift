import Foundation

enum Weekday: Int, Codable, CaseIterable, Hashable {
    // Calendar weekday: 1 = Sunday ... 7 = Saturday
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

struct RecurrenceRule: Codable, Equatable {
    enum Kind: String, Codable { case none, daily, weekly }

    var kind: Kind

    // Common
    var startDate: Date = .distantPast     // inclusive
    var endDate: Date? = nil              // inclusive (optional)
    var interval: Int = 1                 // every N days/weeks

    // Weekly
    var weekdays: Set<Weekday> = []
}
