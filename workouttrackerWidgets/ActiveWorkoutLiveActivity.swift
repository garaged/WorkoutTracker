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
                        if let restText = restInlineText(for: context.state) {
                            Text(restText)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        elapsedTimer(for: context.state)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.currentExerciseName ?? "Resume workout")
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
                Image(systemName: context.state.restMode == .inactive ? "figure.strengthtraining.traditional" : "timer")
            }
            .widgetURL(openURL(for: context))
            .keylineTint(.accentColor)
        }
    }

    private func openURL(for context: ActivityViewContext<ActiveWorkoutActivityAttributes>) -> URL? {
        guard let raw = context.state.openURLString else { return nil }
        return URL(string: raw)
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

    private func restInlineText(for state: ActiveWorkoutActivityAttributes.ContentState) -> String? {
        switch state.restMode {
        case .inactive:
            return nil
        case .running:
            return "Rest"
        case .overdue:
            return "Overdue"
        }
    }

    @ViewBuilder
    private func elapsedTimer(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        Text(timerInterval: state.sessionStartDate...Date.distantFuture, countsDown: false)
    }

    @ViewBuilder
    private func restTimerText(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        if let referenceDate = state.restReferenceDate {
            switch state.restMode {
            case .inactive:
                EmptyView()
            case .running:
                Text(timerInterval: state.stateGeneratedAt...referenceDate, countsDown: true)
            case .overdue:
                HStack(spacing: 4) {
                    Text("Overdue")
                    Text(timerInterval: referenceDate...referenceDate.addingTimeInterval(24 * 60 * 60), countsDown: false)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func restCompactLabel(for state: ActiveWorkoutActivityAttributes.ContentState) -> some View {
        if let referenceDate = state.restReferenceDate {
            switch state.restMode {
            case .inactive:
                EmptyView()
            case .running:
                Text(timerInterval: state.stateGeneratedAt...referenceDate, countsDown: true)
            case .overdue:
                Text(timerInterval: referenceDate...referenceDate.addingTimeInterval(24 * 60 * 60), countsDown: false)
            }
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

                    Text(context.state.currentExerciseName ?? "Resume workout")
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
                    if context.state.restMode == .running {
                        Label {
                            Text(timerInterval: context.state.stateGeneratedAt...referenceDate, countsDown: true)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "timer")
                        }
                        .font(.subheadline)
                    } else {
                        Label {
                            Text(timerInterval: referenceDate...referenceDate.addingTimeInterval(24 * 60 * 60), countsDown: false)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.subheadline)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}
#endif
