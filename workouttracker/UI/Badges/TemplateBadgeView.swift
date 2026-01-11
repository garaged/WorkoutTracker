import SwiftUI

struct TemplateBadgeView: View {
    var body: some View {
        Image(systemName: "wand.and.stars")
            .font(.caption2.weight(.semibold))
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .accessibilityLabel("Template activity")
            // Important: do not steal gestures from the draggable block
            .allowsHitTesting(false)
    }
}
