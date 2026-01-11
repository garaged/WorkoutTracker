import SwiftUI

struct ActivityScheduleSection: View {
    @Bindable var activity: Activity
    let defaultDurationMinutes: Int
    let calendar: Calendar

    init(
        activity: Activity,
        defaultDurationMinutes: Int,
        calendar: Calendar = .current
    ) {
        self.activity = activity
        self.defaultDurationMinutes = defaultDurationMinutes
        self.calendar = calendar
    }

    var body: some View {
        Section("Schedule") {
            Toggle("All-day", isOn: allDayBinding)

            if activity.isAllDay {
                DatePicker("Start date", selection: allDayStartDateBinding, displayedComponents: [.date])
                DatePicker("End date", selection: allDayEndDateInclusiveBinding, displayedComponents: [.date])

                Text("End date is inclusive (like Calendar).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DatePicker("Start", selection: startDateTimeBinding, displayedComponents: [.date, .hourAndMinute])

                Toggle("Has end time", isOn: hasEndBinding)

                if activity.endAt != nil {
                    DatePicker("End", selection: endDateTimeBinding, displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
    }

    // MARK: - Bindings

    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { activity.isAllDay },
            set: { newValue in
                if newValue {
                    ActivityTimeRules.setAllDay(activity, calendar: calendar)
                } else {
                    ActivityTimeRules.unsetAllDay(
                        activity,
                        defaultDurationMinutes: defaultDurationMinutes,
                        calendar: calendar
                    )
                }
            }
        )
    }

    private var startDateTimeBinding: Binding<Date> {
        Binding(
            get: { activity.startAt },
            set: { newValue in
                activity.startAt = newValue
                ActivityTimeRules.ensureEndAfterStart(
                    activity,
                    defaultDurationMinutes: defaultDurationMinutes,
                    calendar: calendar
                )
            }
        )
    }

    private var hasEndBinding: Binding<Bool> {
        Binding(
            get: { activity.endAt != nil },
            set: { enabled in
                if enabled {
                    activity.endAt = calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: activity.startAt)
                } else {
                    activity.endAt = nil
                }
            }
        )
    }

    private var endDateTimeBinding: Binding<Date> {
        Binding(
            get: {
                activity.endAt ?? calendar.date(byAdding: .minute, value: defaultDurationMinutes, to: activity.startAt)!
            },
            set: { newValue in
                activity.endAt = newValue
                ActivityTimeRules.ensureEndAfterStart(
                    activity,
                    defaultDurationMinutes: defaultDurationMinutes,
                    calendar: calendar
                )
            }
        )
    }

    /// All-day start date (midnight).
    private var allDayStartDateBinding: Binding<Date> {
        Binding(
            get: { calendar.startOfDay(for: activity.startAt) },
            set: { newDate in
                let oldStart = calendar.startOfDay(for: activity.startAt)
                let oldEndExclusive = calendar.startOfDay(for: (activity.endAt ?? calendar.date(byAdding: .day, value: 1, to: oldStart)!))

                let spanDays = max(
                    1,
                    calendar.dateComponents([.day], from: oldStart, to: oldEndExclusive).day ?? 1
                )

                let newStart = calendar.startOfDay(for: newDate)
                activity.startAt = newStart
                activity.endAt = calendar.date(byAdding: .day, value: spanDays, to: newStart)!
            }
        )
    }

    /// All-day end date (inclusive UI). Stored as end-exclusive at midnight of the next day.
    private var allDayEndDateInclusiveBinding: Binding<Date> {
        Binding(
            get: {
                let start = calendar.startOfDay(for: activity.startAt)
                let endExclusive = calendar.startOfDay(
                    for: activity.endAt ?? calendar.date(byAdding: .day, value: 1, to: start)!
                )
                // UI shows inclusive end day: endExclusive - 1 day
                return calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? start
            },
            set: { newInclusiveEndDate in
                let start = calendar.startOfDay(for: activity.startAt)
                let endInclusive = calendar.startOfDay(for: newInclusiveEndDate)
                var endExclusive = calendar.date(byAdding: .day, value: 1, to: endInclusive)!

                // Clamp: must be at least 1 day long
                if endExclusive <= start {
                    endExclusive = calendar.date(byAdding: .day, value: 1, to: start)!
                }

                activity.endAt = endExclusive
            }
        )
    }
}
