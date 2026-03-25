import SwiftUI
import Foundation

struct RestTimerView: View {
    let presets: [Int]
    var onFinish: (() -> Void)? = nil

    @ObservedObject private var timer = SessionRestTimerController.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private let cornerRadius: CGFloat = 16

    init(
        presets: [Int] = [30, 60, 90, 120, 180],
        onFinish: (() -> Void)? = nil
    ) {
        self.presets = presets
        self.onFinish = onFinish
    }

    private var usesStackedLayout: Bool {
        AdaptiveLayoutMetrics.shouldStackRestTimerControls(
            verticalSizeClass: verticalSizeClass,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private var statusText: String? {
        guard timer.hasConfiguredTimer else { return nil }
        if timer.displaySeconds < 0 {
            return String(localized: "session.rest.overdue")
        }
        if timer.isRunning {
            return nil
        }
        return timer.displaySeconds == max(0, timer.totalSeconds)
            ? String(localized: "session.rest.ready")
            : String(localized: "session.rest.paused")
    }

    private var accessibilityValue: String {
        AccessibilityLabels.RestTimer.value(
            displaySeconds: timer.displaySeconds,
            isRunning: timer.isRunning,
            hasConfiguredTimer: timer.hasConfiguredTimer,
            totalSeconds: timer.totalSeconds
        )
    }

    private var borderColor: Color {
        if timer.displaySeconds < 0 { return .orange.opacity(0.45) }
        if timer.isRunning { return .accentColor.opacity(0.28) }
        return Color(uiColor: .separator).opacity(0.30)
    }

    private var statusForeground: Color {
        if timer.displaySeconds < 0 { return .orange }
        if timer.isRunning { return .accentColor }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topBar
                .accessibilityReadingOrder(3)

            presetBar
                .accessibilityReadingOrder(1)
        }
        .padding(usesStackedLayout ? 12 : 10)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .accessibilityCardSummary(
            label: AccessibilityLabels.RestTimer.title,
            value: accessibilityValue,
            hint: AccessibilityLabels.RestTimer.hint,
            identifier: "RestTimerView.Container"
        )
        .animation(.workoutAdaptive(reducedMotion: accessibilityReduceMotion), value: timer.displaySeconds)
        .animation(.workoutAdaptive(reducedMotion: accessibilityReduceMotion), value: timer.isRunning)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                if timer.displaySeconds < 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.10))
                }
            }
    }

    @ViewBuilder
    private var topBar: some View {
        if usesStackedLayout {
            VStack(alignment: .leading, spacing: 10) {
                titleAndTimer
                controlsRow
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    titleAndTimer
                    Spacer(minLength: 8)
                    controlsRow
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleAndTimer
                    controlsRow
                }
            }
        }
    }

    private var titleAndTimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(localized: "session.rest.title"))
                    .font(.subheadline.weight(.semibold))

                Text(signedDuration(timer.displaySeconds))
                    .font(
                        .system(
                            usesStackedLayout ? .title3 : .title2,
                            design: .rounded
                        )
                        .weight(.semibold)
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("RestTimerView.TimeLabel")
            }

            if let statusText {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusForeground.opacity(0.14), in: Capsule())
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var controlsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                startPauseButton
                finishButton
                resetButton
            }

            VStack(alignment: .leading, spacing: 8) {
                startPauseButton
                HStack(spacing: 8) {
                    finishButton
                    resetButton
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                startPauseButton
                finishButton
                resetButton
            }
        }
    }

    @ViewBuilder
    private var presetBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { seconds in
                    presetChip(seconds: seconds)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { seconds in
                        presetChip(seconds: seconds)
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
        .accessibilityLabel(AccessibilityLabels.Buttons.restPreset(seconds: seconds))
    }

    private var startPauseButton: some View {
        Button {
            if timer.isRunning {
                timer.pause()
            } else if timer.hasConfiguredTimer {
                timer.resume()
            } else {
                timer.start(seconds: max(1, timer.totalSeconds))
            }
        } label: {
            Label(
                timer.isRunning ? String(localized: "common.pause") : String(localized: "common.start"),
                systemImage: timer.isRunning ? "pause.fill" : "play.fill"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: usesStackedLayout ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .accessibilityLabel(timer.isRunning ? AccessibilityLabels.Buttons.pauseRest : AccessibilityLabels.Buttons.startRest)
    }

    private var finishButton: some View {
        Button {
            if let onFinish {
                onFinish()
            } else {
                _ = timer.finishAndCaptureElapsedSeconds()
            }
        } label: {
            Label(String(localized: "session.rest.finish"), systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: usesStackedLayout ? .infinity : nil)
        }
        .accessibilityIdentifier("RestTimerView.FinishButton")
        .accessibilityLabel(AccessibilityLabels.Buttons.finishRest)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!timer.hasConfiguredTimer)
    }

    private var resetButton: some View {
        Button {
            timer.reset()
        } label: {
            Label(String(localized: "common.reset"), systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: usesStackedLayout ? .infinity : nil)
        }
        .accessibilityLabel(AccessibilityLabels.Buttons.resetRest)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(timer.totalSeconds <= 0)
    }

    private func signedDuration(_ seconds: Int) -> String {
        let base = AppFormatting.duration(seconds: abs(seconds))
        return seconds < 0 ? "-\(base)" : base
    }
}
