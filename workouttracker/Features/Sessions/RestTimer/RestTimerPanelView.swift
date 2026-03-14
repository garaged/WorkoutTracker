import SwiftUI

struct RestTimerPanelView: View {
    @ObservedObject var timer: SessionRestTimerController
        var onDismiss: () -> Void

    private var snapshot: RestTimerSnapshot {
        timer.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(String(localized: "session.rest.title"), systemImage: "timer")
                    .font(.headline)
                Spacer()
                Button {
                    timer.resolveForNextAction()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common.done"))
            }

            Text(displayDurationText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(snapshot.isOverdue ? .orange : snapshot.isReady ? .green : .primary)
                .monospacedDigit()
                .accessibilityIdentifier("RestTimerPanelView.TimeLabel")

            if let statusText {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusBackground, in: Capsule())
                    .foregroundStyle(statusForeground)
                    .accessibilityIdentifier(statusIdentifier)
            }

            HStack(spacing: 10) {
                RestTimerControlsView(options: [15, 30, 60], isEnabled: snapshot.canExtend) { seconds in
                    timer.extend(by: seconds)
                }

                Spacer(minLength: 0)

                Button(String(localized: "common.done")) {
                    timer.resolveForNextAction()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("RestTimerPanelView.DoneButton")
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(snapshot.isOverdue ? .orange.opacity(0.20) : .secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var displayDurationText: String {
        if snapshot.isOverdue {
            return "+\(AppFormatting.duration(seconds: snapshot.overdueSeconds))"
        }

        return AppFormatting.duration(seconds: snapshot.displaySeconds)
    }

    private var statusText: String? {
        if snapshot.isPaused { return String(localized: "session.rest.paused") }
        if snapshot.isReady { return String(localized: "session.rest.ready") }
        if snapshot.isOverdue { return String(localized: "session.rest.overdue") }
        return nil
    }

    private var statusIdentifier: String {
        if snapshot.isPaused { return "RestTimerPanelView.PausedLabel" }
        if snapshot.isReady { return "RestTimerPanelView.ReadyLabel" }
        if snapshot.isOverdue { return "RestTimerPanelView.OverdueLabel" }
        return "RestTimerPanelView.StatusLabel"
    }

    private var statusBackground: Color {
        if snapshot.isReady { return Color.green.opacity(0.14) }
        if snapshot.isOverdue { return Color.orange.opacity(0.14) }
        return Color.secondary.opacity(0.10)
    }

    private var statusForeground: Color {
        if snapshot.isReady { return .green }
        if snapshot.isOverdue { return .orange }
        return .secondary
    }
}
