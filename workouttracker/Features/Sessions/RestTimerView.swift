import SwiftUI
import Combine

struct RestTimerView: View {
    let presets: [Int]
    let autostart: Bool
    var onFinish: (() -> Void)? = nil

    @State private var totalSeconds: Int
    @State private var remainingSeconds: Int
    @State private var isRunning: Bool
    @State private var announcedCountdownSeconds: Set<Int> = []

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cuePlayer = WorkoutCuePlayer.shared

    init(
        initialSeconds: Int = 90,
        presets: [Int] = [30, 60, 90, 120, 180],
        autostart: Bool = true,
        onFinish: (() -> Void)? = nil
    ) {
        self.presets = presets
        self.autostart = autostart
        self.onFinish = onFinish

        let clamped = max(1, initialSeconds)
        _totalSeconds = State(initialValue: clamped)
        _remainingSeconds = State(initialValue: clamped)
        _isRunning = State(initialValue: false)
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
                        announcedCountdownSeconds.removeAll()

                        if autostart {
                            startFreshRun(playStartCue: true)
                        } else {
                            isRunning = false
                        }
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
                    if isRunning {
                        isRunning = false
                    } else {
                        if remainingSeconds <= 0 {
                            remainingSeconds = totalSeconds
                        }

                        let isFreshStart = remainingSeconds == totalSeconds
                        isRunning = true

                        if isFreshStart {
                            announcedCountdownSeconds.removeAll()
                            cuePlayer.play(.restStart)
                        }
                    }
                } label: {
                    Label(isRunning ? "Pause" : "Start",
                          systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isRunning = false
                    remainingSeconds = totalSeconds
                    announcedCountdownSeconds.removeAll()
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
        .onAppear {
            if autostart {
                startFreshRun(playStartCue: true)
            }
        }
        .onReceive(tick) { _ in
            guard isRunning else { return }
            advanceOneSecond()
        }
    }

    private func startFreshRun(playStartCue: Bool) {
        remainingSeconds = totalSeconds
        isRunning = true
        announcedCountdownSeconds.removeAll()

        if playStartCue {
            cuePlayer.play(.restStart)
        }
    }

    private func advanceOneSecond() {
        guard remainingSeconds > 0 else {
            isRunning = false
            return
        }

        if remainingSeconds == 1 {
            remainingSeconds = 0
            isRunning = false
            cuePlayer.play(.restEnd)
            onFinish?()
            return
        }

        let nextValue = remainingSeconds - 1
        remainingSeconds = nextValue

        if nextValue == 3, !announcedCountdownSeconds.contains(nextValue) {
            announcedCountdownSeconds.insert(nextValue)
            cuePlayer.play(.restCountdown)
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
