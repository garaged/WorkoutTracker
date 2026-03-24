import SwiftUI

/// Shared layout thresholds for Dynamic Type and compact environments.
///
/// Why this file lives here:
/// - These breakpoints are cross-feature UI decisions, not screen-specific business logic.
/// - Centralizing them prevents every screen from inventing its own sizing rules.
enum AdaptiveLayoutMetrics {
    static func shouldStackRestTimerControls(
        verticalSizeClass: UserInterfaceSizeClass?,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxLarge
    }

    static func shouldStackSetEditorFields(
        horizontalSizeClass: UserInterfaceSizeClass?,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        dynamicTypeSize.isAccessibilitySize || (horizontalSizeClass == .compact && dynamicTypeSize >= .xLarge)
    }

    static func shouldStackActiveSessionButtons(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxLarge
    }

    static func shouldStackSegmentHeaderProgress(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func compactFieldWidth(base: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? max(base, 82) : base
    }
}
