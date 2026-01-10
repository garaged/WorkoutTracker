import CoreGraphics

struct AutoScrollConfig: Sendable {
    var edgeThreshold: CGFloat = 80     // pts from top/bottom to start scrolling
    var maxSpeed: CGFloat = 900         // pts/sec at the edge
    var hysteresis: CGFloat = 12        // pts to avoid flicker

    static let `default` = AutoScrollConfig()
}
