import SwiftUI

struct RoutineRow: View {
    let title: String
    let onStartNow: () -> Void
    let onScheduleToday: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.thinMaterial)
                    .frame(width: 36, height: 36)

                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title)
                .font(.body.weight(.semibold))

            Spacer()

            Button(action: onScheduleToday) {
                Image(systemName: "calendar.badge.plus")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Schedule for today")

            Button(action: onStartNow) {
                Image(systemName: "play.fill")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Start now")
        }
        .padding(.vertical, 4)
    }
}
