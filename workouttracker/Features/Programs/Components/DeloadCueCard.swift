import SwiftUI

struct DeloadCueCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Deload cue", defaultValue: "Deload cue"), systemImage: "figure.cooldown")
                .font(.headline)
                .foregroundStyle(.teal)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.teal.opacity(0.08))
        )
    }
}
