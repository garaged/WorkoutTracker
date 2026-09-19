import Foundation

/// Product category IDs. Platform Health mappings are a separate capability.
enum QuickStartStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case cardio
    case strengthWeights = "strength_weights"
    case bodyweightFunctional = "bodyweight_functional"
    case hiit
    case danceFitness = "dance_fitness"
    case yoga
    case pilates
    case mobilityStretching = "mobility_stretching"
    case other

    var id: String { rawValue }
    static let defaults: [Self] = [.cardio, .strengthWeights, .bodyweightFunctional, .hiit]

    var localizationKey: String {
        switch self {
        case .cardio: return "quickstart.style.cardio"
        case .strengthWeights: return "quickstart.style.strength_weights"
        case .bodyweightFunctional: return "quickstart.style.bodyweight_functional"
        case .hiit: return "quickstart.style.hiit"
        case .danceFitness: return "quickstart.style.dance_fitness"
        case .yoga: return "quickstart.style.yoga"
        case .pilates: return "quickstart.style.pilates"
        case .mobilityStretching: return "quickstart.style.mobility_stretching"
        case .other: return "quickstart.style.other"
        }
    }
}

enum QuickStartSelectionPolicy {
    enum StartResolution: Equatable {
        case canStart
        case resolveExisting([UUID])
    }
    static func shortlist(favorites: [String], recents: [String], available: Set<String>) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for id in favorites + recents where available.contains(id) {
            if seen.insert(id).inserted { result.append(id) }
            if result.count == 4 { break }
        }
        return result
    }
    static func startResolution(activeSessionIDs: [UUID]) -> StartResolution {
        var seen = Set<UUID>()
        let unique = activeSessionIDs.filter { seen.insert($0).inserted }
        return unique.isEmpty ? .canStart : .resolveExisting(unique)
    }
}
