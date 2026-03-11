import Foundation

public struct TrainingWeek: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 1-based index
    public var index: Int
    public var title: String?
    public var goal: String?
    public var days: [TrainingDay]

    public init(
        id: UUID = UUID(),
        index: Int,
        title: String? = nil,
        goal: String? = nil,
        days: [TrainingDay] = []
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.goal = goal
        self.days = days
    }

    public var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? title!
        : "Week \(index)"
    }

    public var orderedDays: [TrainingDay] {
        days.sorted { $0.index < $1.index }
    }
}

// MARK: - Resilient decoding (generates ids if missing)
extension TrainingWeek {
    private enum CodingKeys: String, CodingKey {
        case id, index, title, goal, days
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.index = (try? c.decode(Int.self, forKey: .index)) ?? 1
        self.title = try? c.decode(String.self, forKey: .title)
        self.goal = try? c.decode(String.self, forKey: .goal)
        self.days = (try? c.decode([TrainingDay].self, forKey: .days)) ?? []
    }
}
