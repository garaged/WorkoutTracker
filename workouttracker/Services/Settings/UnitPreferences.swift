import Foundation

struct UnitPreferences {
    enum Keys {
        static let weightUnitRaw = "prefs.weightUnitRaw"   // "kg" or "lb"
        static let distanceUnitRaw = "prefs.distanceUnitRaw" // "km" or "mi"
    }

    static var weightUnit: WeightUnit {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.weightUnitRaw) ?? WeightUnit.kg.rawValue
            return WeightUnit(rawValue: raw) ?? .kg
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.weightUnitRaw)
        }
    }

    static var distanceUnit: DistanceUnit {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.distanceUnitRaw) ?? DistanceUnit.km.rawValue
            return DistanceUnit(rawValue: raw) ?? .km
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.distanceUnitRaw)
        }
    }
}
