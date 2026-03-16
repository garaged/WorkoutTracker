import SwiftUI
import Foundation

struct RestTimerView: View {
    let presets: [Int]
    var onFinish: (() -> Void)? = nil

    @ObservedObject private var timer = RestTimerController.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let cornerRadius: CGFloat = 16

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topBar
            presetBar
        }
        .padding(isCompactLayout ? 9 : 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.30), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .onChange(of: timer.didFinishToken, initial: false) { _, token in
            guard token != nil else { return }
            onFinish?()
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(String(localized: "session.rest.title"))
                .font(.subheadline.weight(.semibold))

            Text(AppFormatting.duration(seconds: timer.remainingSeconds))
                .font(
                    .system(
                        isCompactLayout ? .title3 : .title2,
                        design: .rounded
                    )
                    .weight(.semibold)
                )
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                playStartCue: UserPreferences.shared.autoStartRest
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
            if timer.isRunning {
                timer.pause()
            } else if timer.remainingSeconds > 0 {
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
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
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
        .disabled(timer.totalSeconds <= 0)
    }

}
