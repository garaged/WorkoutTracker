import SwiftUI

struct SessionSegmentHeaderView: View {
    let kind: WorkoutExerciseSegment
    var progressText: String? = nil
    var isCurrent: Bool = false
    var showsSkipAction: Bool = false
    var onSkip: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var title: String {
        switch kind {
        case .warmUp: return String(localized: "session.segment.warm_up")
        case .main: return String(localized: "session.segment.main")
        case .coolDown: return String(localized: "session.segment.cool_down")
        }
    }

    private var subtitle: String {
        isCurrent ? String(localized: "session.segment.current") : String(localized: "session.segment.label")
    }

    private var skipTitle: String {
        switch kind {
        case .warmUp:
            return String(localized: "session.segment.skip.warm_up")
        case .main:
            return String(localized: "session.segment.main")
        case .coolDown:
            return String(localized: "session.segment.skip.cool_down")
        }
    }

    private var containerID: String {
        isCurrent ? "SessionSegmentHeaderView.Current.\(kind.rawValue)" : "SessionSegmentHeaderView.\(kind.rawValue)"
    }

    private var stacksProgress: Bool {
        verticalSizeClass == .compact || AdaptiveLayoutMetrics.shouldStackSegmentHeaderProgress(dynamicTypeSize: dynamicTypeSize)
    }

    private var segmentIcon: String {
        switch kind {
        case .warmUp: return "flame.fill"
        case .main: return "figure.strengthtraining.traditional"
        case .coolDown: return "wind"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if stacksProgress {
                VStack(alignment: .leading, spacing: 10) {
                    headerTextBlock
                    progressCapsule
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    headerTextBlock
                    Spacer(minLength: 12)
                    progressCapsule
                }
            }

            if showsSkipAction, let onSkip {
                Button(role: .destructive, action: onSkip) {
                    Label(skipTitle, systemImage: "forward.end")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(Text(verbatim: skipTitle))
                .accessibilityHint(Text(verbatim: AccessibilityLabels.Hints.skipSegment(title)))
                .accessibilityIdentifier("WorkoutSession.SkipSegmentButton")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: isCurrent ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityCardSummary(
            label: title,
            value: AccessibilityLabels.Segments.value(isCurrent: isCurrent, progressText: progressText),
            identifier: containerID
        )
    }

    private var headerTextBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: segmentIcon)
                .font(.caption.weight(.bold))
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .padding(8)
                .background((isCurrent ? Color.accentColor : Color.secondary).opacity(0.10), in: Circle())
                .accessibilityDecorative()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isCurrent {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    } else {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(isCurrent ? "SessionSegmentHeaderView.CurrentLabel" : "SessionSegmentHeaderView.Label")

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("SessionSegmentHeaderView.Title.\(kind.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var progressCapsule: some View {
        if let progressText {
            Text(progressText)
                .font(.caption.weight(.medium))
                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((isCurrent ? Color.accentColor : Color.secondary).opacity(0.10), in: Capsule())
                .accessibilityIdentifier("SessionSegmentHeaderView.Progress.\(kind.rawValue)")
                .accessibilityHidden(true)
        }
    }

    private var backgroundStyle: some ShapeStyle {
        if isCurrent {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.04))
    }

    private var borderColor: Color {
        isCurrent ? Color.accentColor.opacity(0.32) : Color.secondary.opacity(0.12)
    }
}
