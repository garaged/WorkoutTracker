import Foundation

/// Process-local clock adapter for quick-start timing.
final class QuickStartClockSource {
    init() {}

    init(
        wallNow: @escaping () -> Date,
        elapsedNow: @escaping () -> Duration,
        epoch: UUID
    ) {}

    func sample() -> QuickStartClockSample {
        QuickStartClockSample(
            wall: Date(timeIntervalSince1970: 0),
            uptime: 0,
            epoch: UUID()
        )
    }
}
