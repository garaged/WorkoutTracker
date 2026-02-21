import Foundation

/// A lightweight “session reflection” mood.
/// Codable so it can participate in backups/exports and SwiftData persistence.
enum SessionReflectionMood: String, Codable, CaseIterable, Identifiable, Hashable {
    case great
    case good
    case neutral
    case tough
    case bad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .great:   return "Great"
        case .good:    return "Good"
        case .neutral: return "Neutral"
        case .tough:   return "Tough"
        case .bad:     return "Bad"
        }
    }

    var emoji: String {
        switch self {
        case .great:   return "😄"
        case .good:    return "🙂"
        case .neutral: return "😐"
        case .tough:   return "😮‍💨"
        case .bad:     return "😞"
        }
    }

    var displayText: String { "\(emoji) \(title)" }
}
