import SwiftUI

struct TodayJumpButton: View {
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Today", systemImage: "calendar")
        }
        .buttonStyle(.bordered)      // nice capsule in the top bar
        .controlSize(.small)
        .disabled(isToday)
        .opacity(isToday ? 0.55 : 1.0)
        .accessibilityHint("Jump to the current day")
    }
}
