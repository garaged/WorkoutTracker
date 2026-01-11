import Foundation

enum ActivityTimeRules {
    static func setAllDay(_ a: Activity, calendar: Calendar = .current) {
        a.isAllDay = true
        let start = calendar.startOfDay(for: a.startAt)
        a.startAt = start
        a.endAt = calendar.date(byAdding: .day, value: 1, to: start)!
    }

    static func unsetAllDay(
        _ a: Activity,
        defaultDurationMinutes: Int,
        calendar: Calendar = .current
    ) {
        a.isAllDay = false

        // If it was a 24h-style all-day span, give it a normal duration so it behaves like timed blocks.
        let end = a.endAt ?? calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!
        if end <= a.startAt || end.timeIntervalSince(a.startAt) >= 23 * 3600 {
            a.endAt = calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!
        } else {
            a.endAt = end
        }
    }

    static func ensureEndAfterStart(
        _ a: Activity,
        defaultDurationMinutes: Int,
        calendar: Calendar = .current
    ) {
        guard let end = a.endAt else { return }
        if end <= a.startAt {
            a.endAt = calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!
        }
    }
}
