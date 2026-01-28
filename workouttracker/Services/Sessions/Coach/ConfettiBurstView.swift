import SwiftUI

struct ConfettiBurstView: View {
    struct Particle: Identifiable {
        let id: Int
        let x: CGFloat
        let drift: CGFloat
        let rot: Double
        let delay: Double
        let size: CGSize
        let color: Color
    }

    let token: UUID

    @State private var animate = false

    private var particles: [Particle] {
        // deterministic-ish based on UUID
        var rng = SeededRandom(seed: token.uuidString.hashValue)
        let colors: [Color] = [.pink, .blue, .green, .orange, .yellow, .purple]

        return (0..<22).map { i in
            Particle(
                id: i,
                x: rng.cgFloat(0.15, 0.85),
                drift: rng.cgFloat(-160, 160),
                rot: rng.double(-260, 260),
                delay: rng.double(0, 0.12),
                size: CGSize(width: rng.cgFloat(5, 9), height: rng.cgFloat(9, 14)),
                color: colors[Int(rng.double(0, Double(colors.count - 1)).rounded())]
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size.width, height: p.size.height)
                        .rotationEffect(.degrees(animate ? p.rot : 0))
                        .position(
                            x: geo.size.width * p.x + (animate ? p.drift : 0),
                            y: animate ? geo.size.height * 0.65 : -20
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 1.25).delay(p.delay), value: animate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .onAppear { animate = true }
        }
    }
}

/// tiny deterministic RNG (so confetti doesn't "jump" during recomposition)
private struct SeededRandom {
    private var state: UInt64
    init(seed: Int) { self.state = UInt64(bitPattern: Int64(seed)) &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        return state
    }

    mutating func double(_ lo: Double, _ hi: Double) -> Double {
        let v = Double(next() % 10_000) / 10_000.0
        return lo + (hi - lo) * v
    }

    mutating func cgFloat(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        CGFloat(double(Double(lo), Double(hi)))
    }
}
