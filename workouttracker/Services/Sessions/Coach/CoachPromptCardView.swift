import SwiftUI

struct CoachPromptCardView: View {
    let title: String
    let message: String
    let suggestedRestSeconds: Int

    let weightActionTitle: String?
    let repsActionTitle: String?

    let onApplyWeight: (() -> Void)?
    let onApplyReps: (() -> Void)?
    let onStartRest: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if let weightActionTitle, let onApplyWeight {
                    Button(action: onApplyWeight) {
                        Text(weightActionTitle)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let repsActionTitle, let onApplyReps {
                    Button(action: onApplyReps) {
                        Text(repsActionTitle)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if let onStartRest {
                    Button(action: onStartRest) {
                        Label("\(suggestedRestSeconds)s", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
