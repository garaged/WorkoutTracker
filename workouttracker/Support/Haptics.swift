import UIKit

enum Haptics {
    /// Light “tick” feedback (perfect for snap boundaries).
    static func tickLight() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }
}
