import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kg
    case lb

    /// Stable identity for SwiftUI `ForEach` / `Picker` rendering.
    public var id: String { rawValue }

    /// User-facing name for settings and labels.
    public var title: String {
        switch self {
        case .kg: return "Kilograms"
        case .lb: return "Pounds"
        }
    }

    /// Localized-friendly short symbol for compact UI.
    public var symbol: String { rawValue }

    /// Combined label for pickers where both name and symbol help clarity.
    public var pickerLabel: String { "\(title) (\(symbol))" }
}
