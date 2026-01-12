import Foundation
import CoreGraphics

struct AutoScrollConfig: Sendable {
    let edgeThreshold: CGFloat
    let maxSpeed: CGFloat
    let hysteresis: CGFloat
    let tickHz: Double

    static let `default` = AutoScrollConfig(
        edgeThreshold: 56,
        maxSpeed: 900,
        hysteresis: 12,
        tickHz: 60
    )
}
