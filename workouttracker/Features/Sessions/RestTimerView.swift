import SwiftUI
import Combine

struct RestTimerView: View {
    let presets: [Int]
    let autostart: Bool
    var onFinish: (() -> Void)? = nil

    @State private var totalSeconds: Int
    @State private var remainingSeconds: Int
    @State private var isRunning: Bool

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        initialSeconds: Int = 90,
        presets: [Int] = [30, 60, 90, 120, 180],
        autostart: Bool = true,
        onFinish: (() -> Void)? = nil
    ) {
        self.presets = presets
        self.autostart = autostart
        self.onFinish = onFinish

        _totalSeconds = State(initialValue: max(1, initialSeconds))
        _remainingSeconds = State(initialValue: max(1, initialSeconds))
        _isRunning = State(initialValue: autostart)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Rest").font(.headline)
                Spacer()
                Text(timeString(remainingSeconds))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { s in
                    Button {
                        totalSeconds = s
                        remainingSeconds = s
                        isRunning = autostart
                    } label: {
                        Text(labelForPreset(s))
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    if remainingSeconds <= 0 { remainingSeconds = totalSeconds }
                    isRunning.toggle()
                } label: {
                    Label(isRunning ? "Pause" : "Start",
                          systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isRunning = false
                    remainingSeconds = totalSeconds
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onReceive(tick) { _ in
            guard isRunning else { return }
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                isRunning = false
                onFinish?()
            }
        }
    }

    private func timeString(_ s: Int) -> String {
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    private func labelForPreset(_ s: Int) -> String {
        if s < 60 { return "\(s)s" }
        if s % 60 == 0 { return "\(s/60)m" }
        return "\(s/60)m \(s%60)s"
    }
}
