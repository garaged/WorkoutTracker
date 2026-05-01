import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct ActiveWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ActiveWorkoutActivityAttributes.self) { context in
            ActiveWorkoutLiveActivityLockScreenView(context: context)
                .widgetURL(openURL(for: context))
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.accentColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.sessionTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        if let setLabel = setLabel(for: context.state) {
                            Text(setLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        restInlineStatus(for: context.state)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        elapsedTimer(for: context.state)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentExerciseName ?? context.attributes.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        Label("Open Workout", systemImage: "arrow.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        if context.state.restMode != .inactive {
                            restTimerText(for: context.state)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(restTimerForeground(for: context.state))
                        } else {
                            elapsedTimer(for: context.state)
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                if context.state.restMode != .inactive {
                    restCompactLabel(for: context.state)
                } else if let setLabel = compactSetLabel(for: context.state) {
                    Text(setLabel)
                } else {
                    Image(systemName: "play.fill")
                }
            } minimal: {
                Image(systemName: minimalSymbol(for: context.state))
            }
            .widgetURL(openURL(for: context))
            .keylineTint(.accentColor)
        }
    }

    private func openURL(for context: ActivityViewContext<ActiveWorkoutActivityAttributes>) -> URL? {
        if let raw = context.state.openURLString,
           let url = URL(string: raw) {
            return url
        }

        return URL(string: "workouttracker://home")
    }

    private func setLabel(for state: ActiveWorkoutActivityAttributes.ContentState) -> String? {
        guard let current = state.currentSetIndex,
              let total = state.totalSets,
              total > 0 else {
            return nil
        }
        return "Set \(current)/\(total)"
    }

    private func compactSetLabel(for state: ActiveWorkoutActivityAttributes.ContentState) -> String? {
        guard let current = state.currentSetIndex,
              let total = state.totalSets,
              total > 0 else {
            return nil
        }
        return "\(current)/\(total)"
    }

    private func minimalSymbol(for state: ActiveWorkoutActivityAttributes.ContentState) -> String {
        switch state.restMode {
        case .inactive:
            return "figure.strengthtraining.traditional"
        case .running:
            return "timer"
        case .overdue:
            return "exclamationmark.triangle.fill"
        }
    }

    private func restTimerForeground(
        for state: ActiveWorkoutActivityAttributes.ContentState
    ) -> some ShapeStyle {
        state.restMode == .overdue ? Color.red : Color.primary
    }

    @ViewBuilder
    private func restInlineStatus(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        switch state.restMode {
        case .inactive:
            EmptyView()
        case .running:
            Text("Rest")
        case .overdue:
            Text("Overdue")
        }
    }

    @ViewBuilder
    private func elapsedTimer(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        Text(timerInterval: state.sessionStartDate...Date.distantFuture, countsDown: false)
    }

    @ViewBuilder
    private func restTimerText(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        if let referenceDate = state.restReferenceDate {
            LiveActivityRestTimerText(
                restMode: state.restMode,
                restEndDate: referenceDate,
                stateGeneratedAt: state.stateGeneratedAt
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func restCompactLabel(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        if let referenceDate = state.restReferenceDate {
            CompactRestTimerText(
                restMode: state.restMode,
                restEndDate: referenceDate,
                stateGeneratedAt: state.stateGeneratedAt
            )
        } else {
            Image(systemName: "timer")
        }
    }
}

@available(iOS 16.1, *)
private struct ActiveWorkoutLiveActivityLockScreenView: View {
    let context: ActivityViewContext<ActiveWorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)

                    Text(context.state.currentExerciseName ?? context.attributes.sessionTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if let current = context.state.currentSetIndex,
                   let total = context.state.totalSets,
                   total > 0 {
                    Text("Set \(current)/\(total)")
                        .font(.subheadline.weight(.semibold))
                }
            }

            HStack(spacing: 14) {
                Label {
                    Text(timerInterval: context.state.sessionStartDate...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.subheadline)

                if context.state.restMode != .inactive,
                   let referenceDate = context.state.restReferenceDate {
                    Divider()
                    Label {
                        LiveActivityRestTimerText(
                            restMode: context.state.restMode,
                            restEndDate: referenceDate,
                            stateGeneratedAt: context.state.stateGeneratedAt
                        )
                        .foregroundStyle(context.state.restMode == .overdue ? .red : .primary)
                    } icon: {
                        Image(systemName: context.state.restMode == .overdue ? "exclamationmark.triangle.fill" : "timer")
                    }
                    .font(.subheadline)
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}

@available(iOS 16.1, *)
private struct LiveActivityRestTimerText: View {
    let restMode: ActiveWorkoutActivityAttributes.ContentState.RestMode
    let restEndDate: Date
    let stateGeneratedAt: Date

    var body: some View {
        switch restMode {
        case .inactive:
            EmptyView()
        case .running:
            Text(timerInterval: stateGeneratedAt...restEndDate, countsDown: true)
                .lineLimit(1)
        case .overdue:
            HStack(spacing: 0) {
                Text("-")
                Text(
                    timerInterval: restEndDate...restEndDate.addingTimeInterval(24 * 60 * 60),
                    countsDown: false
                )
            }
            .lineLimit(1)
        }
    }
}

@available(iOS 16.1, *)
private struct CompactRestTimerText: View {
    let restMode: ActiveWorkoutActivityAttributes.ContentState.RestMode
    let restEndDate: Date
    let stateGeneratedAt: Date

    var body: some View {
        LiveActivityRestTimerText(
            restMode: restMode,
            restEndDate: restEndDate,
            stateGeneratedAt: stateGeneratedAt
        )
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: 38, alignment: .trailing)
    }
}

#endif
