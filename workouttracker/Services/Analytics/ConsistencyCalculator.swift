import Foundation

struct ConsistencyCalculator {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func summary(
        from sessions: [CompletedSessionAnalyticsSample],
        window: DateInterval
    ) -> ConsistencySummary {
        let windowSessions = sessions.filter { window.contains($0.startedAt) }

        let totalWeeks = max(1, weekCount(in: window))
        let completedSessions = windowSessions.filter(\.wasCompleted)

        let activeWeeks = Set(
            completedSessions.map { weekStart(for: $0.startedAt) }
        ).count

        let averageWorkoutsPerWeek = Double(completedSessions.count) / Double(totalWeeks)

        let completionRate: Double?
        if windowSessions.isEmpty {
            completionRate = nil
        } else {
            completionRate = Double(completedSessions.count) / Double(windowSessions.count)
        }

        let availability: ProgressDataAvailability
        if windowSessions.isEmpty {
            availability = .insufficient
        } else if completionRate == nil || activeWeeks == 0 {
            availability = .partial
        } else {
            availability = .full
        }

        return ConsistencySummary(
            window: window,
            activeWeeks: activeWeeks,
            totalWeeks: totalWeeks,
            averageWorkoutsPerWeek: averageWorkoutsPerWeek,
            completionRate: completionRate,
            dataAvailability: availability
        )
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func weekCount(in window: DateInterval) -> Int {
        let start = weekStart(for: window.start)
        let end = weekStart(for: window.end)

        guard start <= end else { return 1 }

        var count = 0
        var cursor = start

        while cursor <= end {
            count += 1
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }

        return max(1, count)
    }
}
