import Foundation

/// Reusable totals for a tracked activity session.
struct TrackedActivityTotals: Equatable, Codable, Sendable {
    var elapsedDuration: TimeInterval
    var distanceMeters: Double?
    var activeEnergyKilocalories: Double?
    var stepCount: Int?

    init(
        elapsedDuration: TimeInterval,
        distanceMeters: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        stepCount: Int? = nil
    ) {
        self.elapsedDuration = max(0, elapsedDuration)
        self.distanceMeters = distanceMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.stepCount = stepCount
    }

    var hasDistance: Bool {
        guard let distanceMeters, distanceMeters > 0 else { return false }
        return true
    }
}
