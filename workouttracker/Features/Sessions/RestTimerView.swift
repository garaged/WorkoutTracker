import SwiftUI
import Foundation

struct RestTimerView: View {
    let presets: [Int]
    var onFinish: (() -> Void)? = nil

    @ObservedObject private var timer = SessionRestTimerController.shared
        @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let cornerRadius: CGFloat = 16
    private let quickExtendOptions = [15, 30, 60]

    init(
        presets: [Int] = [30, 60, 90, 120, 180],
        onFinish: (() -> Void)? = nil
    ) {
        self.presets = presets
        self.onFinish = onFinish
    }

    private var isCompactLayout: Bool {
        verticalSizeClass == .compact
    }

    private var snapshot: RestTimerSnapshot {
        timer.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topBar

            if snapshot.shouldShow {
                controlsBar
            }

            presetBar
        }
        .padding(isCompactLayout ? 9 : 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(overlayStrokeColor, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel(String(localized: "session.rest.title"))
                .accessibilityIdentifier("RestTimerView.Card")
        }
    }

    @ViewBuilder
    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                titleAndTimer
                Spacer(minLength: 8)
                startPauseButton
                resetButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    titleAndTimer
                    Spacer()
                }

                HStack(spacing: 8) {
                    startPauseButton
                    resetButton
                }
            }
        }
    }

    private var titleAndTimer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: "session.rest.title"))
                    .font(.subheadline.weight(.semibold))

                Text(displayDurationText)
                    .font(
                        .system(
                            isCompactLayout ? .title3 : .title2,
                            design: .rounded
                        )
                        .weight(.semibold)
                    )
                    .monospacedDigit()
                    .foregroundStyle(timerTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("RestTimerView.TimeLabel")
            }

            if let status = statusLabelText {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusBackground, in: Capsule())
                    .foregroundStyle(statusForeground)
                    .accessibilityIdentifier(statusIdentifier)
            }
        }
    }

    @ViewBuilder
    private var controlsBar: some View {
        HStack(spacing: 6) {
            RestTimerControlsView(
                options: quickExtendOptions,
                isEnabled: snapshot.canExtend
            ) { seconds in
                timer.extend(by: seconds)
            }

            Spacer(minLength: 0)

            Button {
                timer.resolveForNextAction()
                onFinish?()
            } label: {
                Label(String(localized: "common.done"), systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("RestTimerView.DoneButton")
        }
    }

    @ViewBuilder
    private var presetBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { s in
                    presetChip(seconds: s)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { s in
                        presetChip(seconds: s)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func presetChip(seconds: Int) -> some View {
        Button {
            timer.configure(
                seconds: seconds,
                startImmediately: UserPreferences.shared.autoStartRest,
                playStartCue: UserPreferences.shared.restTimerCueEnabled
            )
        } label: {
            Text(AppFormatting.shortDuration(seconds: seconds))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var startPauseButton: some View {
        Button {
            if snapshot.isRunning {
                timer.pause()
            } else if snapshot.isPaused {
                timer.resume()
            } else if snapshot.mode == .ready || snapshot.mode == .overdue {
                timer.reset()
            } else {
                timer.start(seconds: max(1, timer.totalSeconds))
            }
        } label: {
            Label(
                startPauseTitle,
                systemImage: startPauseSystemImage
            )
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(startPauseDisabled)
        .accessibilityIdentifier("RestTimerView.PrimaryButton")
    }

    private var resetButton: some View {
        Button {
            timer.reset()
        } label: {
            Label(String(localized: "common.reset"), systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!snapshot.canReset)
        .accessibilityIdentifier("RestTimerView.ResetButton")
    }

    private var displayDurationText: String {
        if snapshot.isOverdue {
            return "+\(AppFormatting.duration(seconds: snapshot.overdueSeconds))"
        }

        return AppFormatting.duration(seconds: snapshot.displaySeconds)
    }

    private var statusLabelText: String? {
        if snapshot.isPaused {
            return String(localized: "session.rest.paused")
        }

        if snapshot.isReady {
            return String(localized: "session.rest.ready")
        }

        if snapshot.isOverdue {
            return String(localized: "session.rest.overdue")
        }

        return nil
    }

    private var statusIdentifier: String {
        if snapshot.isPaused { return "RestTimerView.PausedLabel" }
        if snapshot.isReady { return "RestTimerView.ReadyLabel" }
        if snapshot.isOverdue { return "RestTimerView.OverdueLabel" }
        return "RestTimerView.StatusLabel"
    }

    private var timerTint: Color {
        switch snapshot.mode {
        case .inactive, .countdown:
            return .primary
        case .ready:
            return .green
        case .overdue:
            return .orange
        }
    }

    private var overlayStrokeColor: Color {
        switch snapshot.mode {
        case .inactive, .countdown:
            return Color(uiColor: .separator).opacity(0.30)
        case .ready:
            return Color.green.opacity(0.28)
        case .overdue:
            return Color.orange.opacity(0.32)
        }
    }

    private var statusBackground: Color {
        switch snapshot.mode {
        case .ready:
            return Color.green.opacity(0.14)
        case .overdue:
            return Color.orange.opacity(0.14)
        default:
            return Color.secondary.opacity(0.10)
        }
    }

    private var statusForeground: Color {
        switch snapshot.mode {
        case .ready:
            return .green
        case .overdue:
            return .orange
        default:
            return .secondary
        }
    }

    private var startPauseTitle: String {
        if snapshot.isRunning {
            return String(localized: "common.pause")
        }

        if snapshot.isPaused || snapshot.mode == .countdown {
            return String(localized: "common.start")
        }

        return String(localized: "common.reset")
    }

    private var startPauseSystemImage: String {
        if snapshot.isRunning {
            return "pause.fill"
        }

        if snapshot.mode == .ready || snapshot.mode == .overdue {
            return "arrow.counterclockwise"
        }

        return "play.fill"
    }

    private var startPauseDisabled: Bool {
        if snapshot.isRunning { return false }
        if snapshot.isPaused { return false }
        return timer.totalSeconds <= 0
    }
}
