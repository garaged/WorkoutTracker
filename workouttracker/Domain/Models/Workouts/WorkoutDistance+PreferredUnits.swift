import Foundation

extension WorkoutSetPlan {
    func targetDistance(in unit: DistanceUnit) -> Double? {
        guard let value = targetDistance else { return nil }
        return unit.fromKilometers(value)
    }

    /// Stores the planned distance canonically in kilometers.
    func setTargetDistance(_ preferredValue: Double?, preferredUnit: DistanceUnit) {
        guard let preferredValue else {
            targetDistance = nil
            return
        }
        targetDistance = preferredUnit.toKilometers(preferredValue)
    }
}

extension WorkoutSetLog {
    func targetDistance(in unit: DistanceUnit) -> Double? {
        guard let value = targetDistance else { return nil }
        return unit.fromKilometers(value)
    }

    func actualDistance(in unit: DistanceUnit) -> Double? {
        guard let value = actualDistance else { return nil }
        return unit.fromKilometers(value)
    }

    /// Convenience for editable cardio fields that fall back to the target when actual is empty.
    func editableDistance(in unit: DistanceUnit) -> Double? {
        if let actualDistance {
            return unit.fromKilometers(actualDistance)
        }
        if let targetDistance {
            return unit.fromKilometers(targetDistance)
        }
        return nil
    }

    /// Stores the actual distance canonically in kilometers.
    func setActualDistance(_ preferredValue: Double?, preferredUnit: DistanceUnit) {
        guard let preferredValue else {
            actualDistance = nil
            return
        }
        actualDistance = preferredUnit.toKilometers(preferredValue)
    }

    /// Stores the target distance canonically in kilometers.
    func setTargetDistance(_ preferredValue: Double?, preferredUnit: DistanceUnit) {
        guard let preferredValue else {
            targetDistance = nil
            return
        }
        targetDistance = preferredUnit.toKilometers(preferredValue)
    }
}
