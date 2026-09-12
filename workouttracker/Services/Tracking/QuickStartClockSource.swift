import Foundation

/// Process-local clock adapter for quick-start timing.
final class QuickStartClockSource {
    private let wallNow: () -> Date
    private let elapsedNow: () -> Duration
    private let epoch: UUID

    convenience init() {
        let clock = ContinuousClock()
        let origin = clock.now
        self.init(
            wallNow: Date.init,
            elapsedNow: { origin.duration(to: clock.now) },
            epoch: UUID()
        )
    }

    init(
        wallNow: @escaping () -> Date,
        elapsedNow: @escaping () -> Duration,
        epoch: UUID
    ) {
        self.wallNow = wallNow
        self.elapsedNow = elapsedNow
        self.epoch = epoch
    }

    func sample() -> QuickStartClockSample {
        let components = elapsedNow().components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        return QuickStartClockSample(
            wall: wallNow(),
            uptime: max(0, seconds),
            epoch: epoch
        )
    }
}
