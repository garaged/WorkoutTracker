// File: workouttracker/Features/Sessions/RestTimer/RestTimerPanelView.swift

import SwiftUI

struct RestTimerPanelView: View {
    @ObservedObject var timer: RestTimerController
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Rest", systemImage: "timer")
                    .font(.headline)
                Spacer()
                Button {
                    timer.stop()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End rest")
            }

            Text(timeString(timer.remainingSeconds))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 10) {
                Button("-15s") { timer.extend(by: -15) }
                    .disabled(!timer.isRunning)

                Button("+15s") { timer.extend(by: 15) }
                    .disabled(!timer.isRunning)

                Button("Done") {
                    timer.stop()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func timeString(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
