import Foundation

public enum DistanceUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case km
    case mi

    /// Stable identity for SwiftUI `ForEach` / `Picker` rendering.
    public var id: String { rawValue }

    /// User-facing name for settings and labels.
    public var title: String {
        switch self {
        case .km: return "Kilometers"
        case .mi: return "Miles"
        }
    }

    /// Compact suffix for fields and summaries.
    public var symbol: String { rawValue }

    /// Combined label for pickers where both name and symbol help clarity.
    public var pickerLabel: String { "\(title) (\(symbol))" }
}
