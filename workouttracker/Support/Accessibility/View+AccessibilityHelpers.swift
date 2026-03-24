import SwiftUI

/// Shared accessibility helpers used across multiple features.
///
/// Why this file lives here:
/// - It keeps semantic grouping and icon-only control labels consistent.
/// - It avoids repeating the same accessibility boilerplate in every screen.
struct AccessibilityCardSummaryModifier: ViewModifier {
    let label: String
    let value: String?
    let hint: String?
    let identifier: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(label))
            .appAccessibilityValue(value)
            .appAccessibilityHint(hint)
            .appAccessibilityIdentifier(identifier)
    }
}

struct AccessibilityIconControlModifier: ViewModifier {
    let label: String
    let hint: String?
    let identifier: String?

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(Text(label))
            .appAccessibilityHint(hint)
            .appAccessibilityIdentifier(identifier)
    }
}

extension View {
    func accessibilityCardSummary(
        label: String,
        value: String? = nil,
        hint: String? = nil,
        identifier: String? = nil
    ) -> some View {
        modifier(
            AccessibilityCardSummaryModifier(
                label: label,
                value: value,
                hint: hint,
                identifier: identifier
            )
        )
    }

    func accessibilityIconControl(
        label: String,
        hint: String? = nil,
        identifier: String? = nil
    ) -> some View {
        modifier(
            AccessibilityIconControlModifier(
                label: label,
                hint: hint,
                identifier: identifier
            )
        )
    }

    func accessibilityDecorative() -> some View {
        accessibilityHidden(true)
    }

    @ViewBuilder
    fileprivate func appAccessibilityValue(_ value: String?) -> some View {
        if let value, !value.isEmpty {
            accessibilityValue(Text(value))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func appAccessibilityHint(_ hint: String?) -> some View {
        if let hint, !hint.isEmpty {
            accessibilityHint(Text(hint))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func appAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier, !identifier.isEmpty {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

extension Animation {
    static func workoutAdaptive(reducedMotion: Bool) -> Animation {
        reducedMotion ? .easeOut(duration: 0.12) : .snappy
    }
}
