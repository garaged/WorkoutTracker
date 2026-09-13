import Foundation

/// Versioned value stored on a canonical record; never a second workout database.
struct QuickStartTimingPayload: Codable, Equatable, Sendable {
    enum ValidationError: Error { case unsupportedVersion, emptyStyle }
    let version: Int
    let styleRaw: String
    let timing: QuickStartTimingState

    init(styleRaw: String, timing: QuickStartTimingState) throws {
        guard !styleRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyStyle
        }
        try timing.validatePersistedState()
        version = 1
        self.styleRaw = styleRaw
        self.timing = timing
    }

    var style: QuickStartStyle? { QuickStartStyle(rawValue: styleRaw) }

    private enum CodingKeys: String, CodingKey { case version, styleRaw, timing }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .version) == 1 else {
            throw ValidationError.unsupportedVersion
        }
        try self.init(styleRaw: container.decode(String.self, forKey: .styleRaw),
                      timing: container.decode(QuickStartTimingState.self, forKey: .timing))
    }
}
