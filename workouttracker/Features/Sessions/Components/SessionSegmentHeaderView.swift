import SwiftUI

struct SessionSegmentHeaderView: View {
    let kind: WorkoutExerciseSegment
    var progressText: String? = nil
    var isCurrent: Bool = false
    var showsSkipAction: Bool = false
    var onSkip: (() -> Void)? = nil

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary))
                        .accessibilityIdentifier(isCurrent ? "SessionSegmentHeaderView.CurrentLabel" : "SessionSegmentHeaderView.Label")

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("SessionSegmentHeaderView.Title.\(kind.rawValue)")
                }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(verbatim: headerAccessibilityLabel))

                Spacer(minLength: 12)

                if let progressText {
                    Text(progressText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityIdentifier("SessionSegmentHeaderView.Progress.\(kind.rawValue)")
                }
            }

            if showsSkipAction, let onSkip {
                Button(role: .destructive, action: onSkip) {
                    Label(skipTitle, systemImage: "forward.end")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(Text(verbatim: skipTitle))
                .accessibilityValue(Text(verbatim: title))
                .accessibilityIdentifier("WorkoutSession.SkipSegmentButton")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(containerID)
    }

    private var backgroundStyle: some ShapeStyle {
        if isCurrent {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.04))
    }

    private var headerAccessibilityLabel: String {
        var parts = [subtitle, title]
        if let progressText, !progressText.isEmpty {
            parts.append(progressText)
        }
        return parts.joined(separator: ". ")
    }

    private var borderColor: Color {
        isCurrent ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.12)
    }
}
