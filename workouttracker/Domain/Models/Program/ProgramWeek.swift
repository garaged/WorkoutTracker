import Foundation

public struct ProgramWeek: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var index: Int
    public var title: String?
    public var goal: String?
    public var days: [ProgramDay]

    public init(
        id: UUID = UUID(),
        index: Int,
        title: String? = nil,
        goal: String? = nil,
        days: [ProgramDay] = []
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

    public var orderedDays: [ProgramDay] {
        days.sorted { $0.index < $1.index }
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []
        let dayIndexes = days.map(\.index)

        if Set(dayIndexes).count != dayIndexes.count {
            issues.append("Duplicate day indexes.")
        }

        for day in days {
            issues.append(contentsOf: day.validationIssues().map { "Day \(day.index): \($0)" })
        }

        return issues
    }
}

extension ProgramWeek {
    private enum CodingKeys: String, CodingKey {
        case id
        case index
        case title
        case goal
        case days
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.index = (try? c.decode(Int.self, forKey: .index)) ?? 1
        self.title = try? c.decode(String.self, forKey: .title)
        self.goal = try? c.decode(String.self, forKey: .goal)
        self.days = (try? c.decode([ProgramDay].self, forKey: .days)) ?? []
    }
}
