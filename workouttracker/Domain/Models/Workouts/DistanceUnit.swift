import Foundation

enum DistanceUnit: String, Codable, CaseIterable, Identifiable {
    case km
    case mi

    /// Stable identity for SwiftUI `ForEach` / `Picker` rendering.
    var id: String { rawValue }

    /// User-facing name for settings and labels.
    var title: String {
        switch self {
        case .km: return "Kilometers"
        case .mi: return "Miles"
        }
    }

    /// Compact suffix for fields and summaries.
    var symbol: String { rawValue }

    /// Combined label for pickers where both name and symbol help clarity.
    var pickerLabel: String { "\(title) (\(symbol))" }
}
