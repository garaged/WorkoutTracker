import SwiftUI

struct RestTimerView: View {
    let presets: [Int]
    var onFinish: (() -> Void)? = nil

    @ObservedObject private var timer = RestTimerController.shared

    init(
        presets: [Int] = [30, 60, 90, 120, 180],
        onFinish: (() -> Void)? = nil
    ) {
        self.presets = presets
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Rest").font(.headline)
                Spacer()
                Text(timeString(timer.remainingSeconds))
                    .font(.system(.title2, design: .rounded).monospacedDigit())
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { s in
                    Button {
                        timer.configure(
                            seconds: s,
                            startImmediately: UserPreferences.shared.autoStartRest,
                            playStartCue: UserPreferences.shared.autoStartRest
                        )
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
                    if timer.isRunning {
                        timer.pause()
                    } else if timer.remainingSeconds > 0 {
                        timer.resume()
                    } else {
                        timer.start(seconds: max(1, timer.totalSeconds))
                    }
                } label: {
                    Label(timer.isRunning ? "Pause" : "Start",
                          systemImage: timer.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    timer.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(timer.totalSeconds <= 0)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: timer.didFinishToken, initial: false) { _, token in
            guard token != nil else { return }
            onFinish?()
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
