import Foundation

struct DayActivityBuckets {
    var allDay: [Activity]
    var multiDay: [Activity]
    var timed: [Activity]
}

enum DayActivityBucketer {
    static func bucket(
        activities: [Activity],
        dayStart: Date,
        defaultDurationMinutes: Int,
        calendar: Calendar = .current
    ) -> DayActivityBuckets {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        var allDay: [Activity] = []
        var multiDay: [Activity] = []
        var timed: [Activity] = []

        for a in activities {
            let start = a.startAt
            let end = resolvedEnd(for: a, defaultDurationMinutes: defaultDurationMinutes, calendar: calendar)

            // Only consider activities that overlap this day at all.
            guard end > dayStart, start < dayEnd else { continue }

            let startDay = calendar.startOfDay(for: start)
            // subtract 1 second to treat “ends exactly at midnight” as ending on previous day
            let endDay = calendar.startOfDay(for: end.addingTimeInterval(-1))

            let spansMultipleDays = startDay != endDay

            let coversWholeDay = start <= dayStart && end >= dayEnd
            let inferredAllDay = coversWholeDay && (end.timeIntervalSince(start) >= 23 * 3600)

            // If you add Activity.isAllDay later, this line becomes the “source of truth”.
            let explicitAllDay = a.isAllDay
            let isAllDay = explicitAllDay || inferredAllDay

            if isAllDay {
                if spansMultipleDays {
                    multiDay.append(a)
                } else {
                    allDay.append(a)
                }
                continue
            }

            if spansMultipleDays || start < dayStart || end > dayEnd {
                multiDay.append(a)
            } else {
                timed.append(a)
            }
        }

        // Sorts: stable + expected in calendar UIs
        allDay.sort { $0.startAt < $1.startAt }
        multiDay.sort { $0.startAt < $1.startAt }
        timed.sort { $0.startAt < $1.startAt }

        return DayActivityBuckets(allDay: allDay, multiDay: multiDay, timed: timed)
    }

    static func resolvedEnd(
        for a: Activity,
        defaultDurationMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        if let e = a.endAt { return e }
        return calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: a.startAt)!
    }
}
