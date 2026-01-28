import Foundation

extension WorkoutSetLog {
    func weight(in unit: WeightUnit) -> Double? {
        guard let w = weight else { return nil }
        return weightUnit.convert(w, to: unit)
    }

    func targetWeight(in unit: WeightUnit) -> Double? {
        guard let w = targetWeight else { return nil }
        return targetWeightUnit.convert(w, to: unit)
    }

    /// Sets actual weight assuming the passed value is expressed in `preferredUnit`.
    func setWeight(_ preferredValue: Double?, preferredUnit: WeightUnit) {
        weight = preferredValue
        weightUnit = preferredUnit
    }

    /// Sets target weight assuming the passed value is expressed in `preferredUnit`.
    func setTargetWeight(_ preferredValue: Double?, preferredUnit: WeightUnit) {
        targetWeight = preferredValue
        targetWeightUnit = preferredUnit
    }
}
