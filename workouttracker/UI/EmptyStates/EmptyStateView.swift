import SwiftUI

/// A consistent, reusable “blank slate” view for places where the user has no data yet.
///
/// Why this exists:
/// - It keeps empty states across the app visually consistent.
/// - It keeps microcopy in one place per screen, instead of each screen reinventing layout.
/// - It avoids the prototype-y look of a list full of zeros.
struct EmptyStateView: View {
    struct Action {
        let title: String
        let systemImage: String?
        let role: ButtonRole?
        let handler: () -> Void

        init(
            _ title: String,
            systemImage: String? = nil,
            role: ButtonRole? = nil,
            handler: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.role = role
            self.handler = handler
        }
    }

    let title: String
    let message: String?
    let systemImage: String
    var primaryAction: Action? = nil
    var secondaryAction: Action? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: 10) {
                    if let a = primaryAction {
                        Button(role: a.role) {
                            a.handler()
                        } label: {
                            if let icon = a.systemImage {
                                Label(a.title, systemImage: icon)
                            } else {
                                Text(a.title)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let a = secondaryAction {
                        Button(role: a.role) {
                            a.handler()
                        } label: {
                            if let icon = a.systemImage {
                                Label(a.title, systemImage: icon)
                            } else {
                                Text(a.title)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        // VoiceOver: read it as one coherent “state”, not a bunch of separate pieces.
        .accessibilityElement(children: .combine)
    }
}
