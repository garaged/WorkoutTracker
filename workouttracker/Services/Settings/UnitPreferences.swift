import Foundation

struct UnitPreferences {
    enum Keys {
        static let weightUnitRaw = "prefs.weightUnitRaw" // "kg" or "lb"
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
}
