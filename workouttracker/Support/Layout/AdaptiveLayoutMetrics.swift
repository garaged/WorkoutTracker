import SwiftUI

/// Shared layout thresholds for Dynamic Type and compact environments.
///
/// Why this file lives here:
/// - These breakpoints are cross-feature UI decisions, not screen-specific business logic.
/// - Centralizing them prevents every screen from inventing its own sizing rules.
enum AdaptiveLayoutMetrics {

    static let setEditorMiddleWeights: [CGFloat] = [0.42, 0.58]

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

    static func shouldStackSessionSummaryMetrics(
        verticalSizeClass: UserInterfaceSizeClass?,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        verticalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func shouldStackBottomActionBar(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func shouldStackExerciseHeader(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    static func shouldStackActiveSessionCardHeader(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    static func shouldUseSingleColumnHomeTiles(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func shouldStackProgressCardHeader(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    static func shouldUseSingleColumnProgressStats(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func shouldStackExerciseDetailHeader(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    static func shouldStackExerciseDetailMetrics(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func shouldStackProgressDetailRow(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge
    }

    static func shouldUseSingleColumnReflectionMoodGrid(dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .accessibility1
    }

    static func compactFieldWidth(base: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? max(base, 82) : base
    }
}
