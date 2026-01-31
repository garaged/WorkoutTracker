import Foundation

enum EquipmentCatalog {

    struct Item: Hashable, Identifiable {
        let id: String        // canonical tag, e.g. "dumbbell"
        let label: String     // e.g. "Dumbbells"
        let symbol: String    // SF Symbol
    }

    // Canonical items (the tags you store in Exercise.equipmentTagsRaw)
    static let common: [Item] = [
        .init(id: "dumbbell",        label: "Dumbbells",        symbol: "dumbbell.fill"),
        .init(id: "barbell",         label: "Barbell",          symbol: "figure.strengthtraining.traditional"),
        .init(id: "kettlebell",      label: "Kettlebell",       symbol: "figure.strengthtraining.traditional"),
        .init(id: "plates",          label: "Weight Plates",    symbol: "circle.grid.3x3.fill"),

        .init(id: "bench",           label: "Bench",            symbol: "bed.double.fill"),
        .init(id: "pullupbar",       label: "Pull-up Bar",      symbol: "figure.pullup"),
        .init(id: "bands",           label: "Resistance Bands", symbol: "circle.dashed"),

        .init(id: "cable",           label: "Cable Machine",    symbol: "cable.connector"),
        .init(id: "smith",           label: "Smith Machine",    symbol: "square.split.2x2"),
        .init(id: "legpress",        label: "Leg Press",        symbol: "figure.strengthtraining.traditional"),

        .init(id: "treadmill",       label: "Treadmill",        symbol: "figure.run"),
        .init(id: "bike",            label: "Stationary Bike",  symbol: "bicycle"),
        .init(id: "rower",           label: "Rowing Machine",   symbol: "figure.rower")
    ]

    static func label(for tag: String) -> String {
        if let match = common.first(where: { $0.id == tag }) { return match.label }
        return tag   // fallback for custom tags
    }

    static func symbol(for tag: String) -> String {
        if let match = common.first(where: { $0.id == tag }) { return match.symbol }
        return "wrench.and.screwdriver"
    }

    /// Convert free-form text into a canonical tag.
    /// "Pull-up Bar" -> "pullupbar"
    static func slugify(_ raw: String) -> String {
        let lower = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let allowed = lower.filter { $0.isLetter || $0.isNumber }
        return allowed
    }
}
