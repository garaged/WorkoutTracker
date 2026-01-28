import Foundation

extension WeightUnit {
    /// Exact-ish constant used by most fitness apps.
    private static let lbPerKg: Double = 2.2046226218

    func convert(_ value: Double, to target: WeightUnit) -> Double {
        if self == target { return value }

        switch (self, target) {
        case (.kg, .lb):
            return value * Self.lbPerKg
        case (.lb, .kg):
            return value / Self.lbPerKg
        default:
            return value
        }
    }

    /// A convenience for UI labels.
    var label: String { rawValue }
}
