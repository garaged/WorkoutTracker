import Foundation

nonisolated enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
    // Calendar weekday: 1 = Sunday ... 7 = Saturday
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

nonisolated struct RecurrenceRule: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case none, daily, weekly }

    var kind: Kind
    var startDate: Date = .distantPast
    var endDate: Date? = nil
    var interval: Int = 1
    var weekdays: Set<Weekday> = [] // used when weekly
}

extension RecurrenceRule {
    func matches(day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: startDate)

        if dayStart < start { return false }
        if let endDate {
            let end = calendar.startOfDay(for: endDate)
            if dayStart > end { return false }
        }

        switch kind {
        case .none:
            return calendar.isDate(dayStart, inSameDayAs: start)

        case .daily:
            let diff = calendar.dateComponents([.day], from: start, to: dayStart).day ?? 0
            return diff >= 0 && (diff % max(interval, 1) == 0)

        case .weekly:
            let diffWeeks = calendar.dateComponents([.weekOfYear], from: start, to: dayStart).weekOfYear ?? 0
            if diffWeeks < 0 || (diffWeeks % max(interval, 1) != 0) { return false }

            let weekdayInt = calendar.component(.weekday, from: dayStart)
            guard let wd = Weekday(rawValue: weekdayInt) else { return false }
            return weekdays.contains(wd)
        }
    }
}
