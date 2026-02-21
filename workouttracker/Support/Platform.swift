// workouttracker/Support/Platform.swift
import SwiftUI
import UIKit

/// Lightweight, view-friendly platform traits.
/// Use via: `@Environment(\.platform) private var platform`
struct PlatformContext: Equatable {
    var isPad: Bool
    var horizontalSizeClass: UserInterfaceSizeClass?
    var verticalSizeClass: UserInterfaceSizeClass?

    /// iPad (or any regular-width environment) benefits from split navigation + more whitespace.
    var prefersSplitNavigation: Bool {
        isPad || horizontalSizeClass == .regular
    }

    var isCompactWidth: Bool { horizontalSizeClass == .compact }
    var isRegularWidth: Bool { horizontalSizeClass == .regular }
}

private struct PlatformContextKey: EnvironmentKey {
    static let defaultValue = PlatformContext(isPad: false, horizontalSizeClass: nil, verticalSizeClass: nil)
}

extension EnvironmentValues {
    var platform: PlatformContext {
        get { self[PlatformContextKey.self] }
        set { self[PlatformContextKey.self] = newValue }
    }
}

private struct PlatformContextProvider: ViewModifier {
    @Environment(\.horizontalSizeClass) private var h
    @Environment(\.verticalSizeClass) private var v

    func body(content: Content) -> some View {
        content.environment(
            \.platform,
            PlatformContext(
                isPad: UIDevice.current.userInterfaceIdiom == .pad,
                horizontalSizeClass: h,
                verticalSizeClass: v
            )
        )
    }
}

extension View {
    /// Call once at the top of the app (WindowGroup root).
    func providePlatformContext() -> some View {
        modifier(PlatformContextProvider())
    }

    /// Constrain “form/list” style screens so they don’t go comically wide on iPad.
    func readableWidth(max: CGFloat = 860) -> some View {
        self.frame(maxWidth: max).frame(maxWidth: .infinity)
    }

    /// Small ergonomic polish for iPad lists.
    @ViewBuilder
    func platformListChrome(_ platform: PlatformContext) -> some View {
        if platform.isPad {
            self.listStyle(.insetGrouped)
        } else {
            self.listStyle(.plain)
        }
    }
}
