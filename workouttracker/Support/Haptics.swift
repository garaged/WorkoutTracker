import UIKit

enum Haptics {
    private static var isEnabled: Bool {
        UserPreferences.shared.hapticsEnabled
    }

    /// Light “tick” feedback (perfect for snap boundaries).
    static func tickLight() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
