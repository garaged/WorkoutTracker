import SwiftUI

struct SessionRecoveryPrompt: View {
    let title: String
    let message: String
    let onResume: () -> Void
    let onFinishNow: () -> Void
    let onDiscard: () -> Void
    let onKeepForLater: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    Button(action: onResume) {
                        Label(String(localized: "Resume"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onFinishNow) {
                        Label(String(localized: "Finish now"), systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onKeepForLater) {
                        Label(String(localized: "Keep for later"), systemImage: "clock")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: onDiscard) {
                        Label(String(localized: "Discard"), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(String(localized: "Session recovery"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
