import SwiftUI

struct NextRecommendedActionCard: View {
    let recommendation: ProgramRecommendation
    let nextActionable: PlannedProgramDay?
    let onOpenCalendar: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                String(localized: "Recommended Next Action", defaultValue: "Recommended Next Action"),
                systemImage: "arrow.forward.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(.orange)

            Text(primaryText)
                .font(.subheadline.weight(.semibold))

            Text(secondaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onOpenCalendar, nextActionable != nil {
                Button {
                    onOpenCalendar()
                } label: {
                    Label(String(localized: "Open in Calendar", defaultValue: "Open in Calendar"), systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
    }

    private var primaryText: String {
        switch recommendation.kind {
        case .startWeek:
            return String(
                format: String(
                    localized: "Recommended next action: start Week %1$lld with Day %2$lld.",
                    defaultValue: "Recommended next action: start Week %1$lld with Day %2$lld."
                ),
                Int64(recommendation.weekIndex ?? 1),
                Int64(recommendation.dayIndex ?? 1)
            )
        case .advanceToNextDay:
            return String(
                format: String(
                    localized: "Recommended next action: complete Day %lld.",
                    defaultValue: "Recommended next action: complete Day %lld."
                ),
                Int64(recommendation.dayIndex ?? 1)
            )
        case .completeMissedDay:
            return String(
                format: String(
                    localized: "Recommended next action: complete Day %lld before advancing.",
                    defaultValue: "Recommended next action: complete Day %lld before advancing."
                ),
                Int64(recommendation.dayIndex ?? 1)
            )
        case .repeatWeek:
            return String(
                format: String(
                    localized: "Recommended next action: repeat Week %lld.",
                    defaultValue: "Recommended next action: repeat Week %lld."
                ),
                Int64(recommendation.weekIndex ?? 1)
            )
        case .completeProgram:
            return String(localized: "Program complete", defaultValue: "Program complete")
        }
    }

    private var secondaryText: String {
        switch recommendation.reason {
        case .weekNotStarted:
            return String(localized: "This week has no completed sessions yet.", defaultValue: "This week has no completed sessions yet.")
        case .nextIncompleteDay:
            if let nextActionable {
                let dateText = nextActionable.scheduledDate.formatted(date: .abbreviated, time: .omitted)
                return String(
                    format: String(
                        localized: "programs.recommendation.next_day_detail",
                        defaultValue: "Day %1$lld %2$@ • %3$@"
                    ),
                    Int64(nextActionable.dayIndex),
                    nextActionable.title,
                    dateText
                )
            }
            return String(localized: "Complete the next scheduled training day.", defaultValue: "Complete the next scheduled training day.")
        case .outstandingMissedDay:
            return String(localized: "You missed a scheduled day. Complete it before advancing.", defaultValue: "You missed a scheduled day. Complete it before advancing.")
        case .missedRequiredDays:
            return String(localized: "Repeat this week to rebuild consistency.", defaultValue: "Repeat this week to rebuild consistency.")
        case .programFinished:
            return String(localized: "All scheduled program days are complete.", defaultValue: "All scheduled program days are complete.")
        }
    }

}
