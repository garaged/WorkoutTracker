import SwiftUI

struct ProgramDayRow: View {
    let day: PlannedProgramDay
    let isRoutineAvailable: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconTint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    String(
                        format: String(localized: "programs.day_row.title", defaultValue: "Day %1$lld • %2$@"),
                        Int64(day.dayIndex),
                        day.title
                    )
                )
                    .font(.subheadline.weight(.semibold))

                Text(day.scheduledDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let routineSlug = day.routineSlug, !routineSlug.isEmpty {
                    Text(routineSlug)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !isRoutineAvailable {
                    Text(String(localized: "Routine unavailable", defaultValue: "Routine unavailable"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text(stateText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconTint)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch day.state {
        case .rest: return "bed.double.fill"
        case .upcoming: return "circle"
        case .scheduledToday: return "calendar.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        }
    }

    private var iconTint: Color {
        switch day.state {
        case .rest: return .secondary
        case .upcoming: return .secondary
        case .scheduledToday: return .orange
        case .completed: return .green
        case .missed: return .orange
        }
    }

    private var stateText: String {
        switch day.state {
        case .rest: return String(localized: "Rest", defaultValue: "Rest")
        case .upcoming: return String(localized: "Upcoming", defaultValue: "Upcoming")
        case .scheduledToday: return String(localized: "Today", defaultValue: "Today")
        case .completed: return String(localized: "Done", defaultValue: "Done")
        case .missed: return String(localized: "Missed", defaultValue: "Missed")
        }
    }
}
