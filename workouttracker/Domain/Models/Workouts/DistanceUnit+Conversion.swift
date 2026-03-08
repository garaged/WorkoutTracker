import Foundation

extension DistanceUnit {
    /// Exact-ish constant used by most health / mapping apps.
    private static let milesPerKilometer: Double = 0.6213711922

    func convert(_ value: Double, to target: DistanceUnit) -> Double {
        if self == target { return value }

        switch (self, target) {
        case (.km, .mi):
            return value * Self.milesPerKilometer
        case (.mi, .km):
            return value / Self.milesPerKilometer
        default:
            return value
        }
    }

    /// Converts a canonical kilometer value into the user's preferred display unit.
    func fromKilometers(_ value: Double) -> Double {
        DistanceUnit.km.convert(value, to: self)
    }

    /// Converts a user-entered value into canonical kilometers for storage.
    func toKilometers(_ value: Double) -> Double {
        convert(value, to: .km)
    }

    /// A convenience for UI labels.
    var label: String { rawValue }

    /// Smallest step used by +/- controls in distance fields.
    var stepSize: Double { 0.1 }
}
