import Foundation

extension Date {
    /// "YYYY-MM-DD" based on calendar startOfDay.
    func dayKey(calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: self)
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Parse "YYYY-MM-DD" back into a Date at start of day in the provided calendar.
    init?(dayKey: String, calendar: Calendar = .current) {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else { return nil }

        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = 0
        comps.minute = 0
        comps.second = 0

        guard let date = calendar.date(from: comps) else { return nil }
        self = calendar.startOfDay(for: date)
    }

    /// Convenience: startOfDay in a given calendar.
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
