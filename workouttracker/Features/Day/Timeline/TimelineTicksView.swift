import SwiftUI

struct TimelineTicksView: View {
    let totalMinutes: Int
    let hourHeight: CGFloat
    let snapMinutes: Int

    private var minuteHeight: CGFloat { hourHeight / 60.0 }
    private var contentHeight: CGFloat { CGFloat(totalMinutes) * minuteHeight }

    var body: some View {
        Canvas { ctx, size in
            let step = max(1, snapMinutes)

            for m in stride(from: 0, through: totalMinutes, by: step) {
                // ✅ Skip hour lines: TimelineGrid already draws them
                if m % 60 == 0 { continue }

                let y = CGFloat(m) * minuteHeight
                if y < 0 || y > size.height { continue }

                let isHalf = (m % 30 == 0)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))

                let lineWidth: CGFloat = isHalf ? 0.9 : 0.5
                let opacity: Double = isHalf ? 0.28 : 0.14

                ctx.stroke(
                    path,
                    with: .color(.secondary.opacity(opacity)),
                    lineWidth: lineWidth
                )
            }
        }
        .frame(height: contentHeight)
        .allowsHitTesting(false) // ✅ never steal gestures
    }
}
