import Foundation

/// Versioned value stored on a canonical record; never a second workout database.
struct QuickStartTimingPayload: Codable, Equatable, Sendable {
    let version: Int
    let styleRaw: String
    let timing: QuickStartTimingState

    init(styleRaw: String, timing: QuickStartTimingState) throws {
        version = 1
        self.styleRaw = styleRaw
        self.timing = timing
    }

    var style: QuickStartStyle? { QuickStartStyle(rawValue: styleRaw) }
}
