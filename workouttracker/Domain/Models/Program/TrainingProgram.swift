import Foundation

public struct TrainingProgram: Identifiable, Codable, Hashable, Sendable {
    public enum Level: String, Codable, CaseIterable, Hashable, Sendable {
        case beginner
        case intermediate
        case advanced
        case unknown
    }

    public var id: UUID
    /// Stable human-friendly identifier for catalog + filenames
    public var slug: String
    public var name: String
    public var summary: String?
    public var author: String?
    public var level: Level
    public var tags: [String]
    public var equipment: [String]
    public var weeks: [ProgramWeek]
    public var source: ProgramSource
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        slug: String? = nil,
        name: String,
        summary: String? = nil,
        author: String? = nil,
        level: Level = .unknown,
        tags: [String] = [],
        equipment: [String] = [],
        weeks: [ProgramWeek] = [],
        source: ProgramSource = .custom,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = TrainingProgram.makeSlug(slug?.isEmpty == false ? slug! : name)
        self.summary = summary
        self.author = author
        self.level = level
        self.tags = tags
        self.equipment = equipment
        self.weeks = weeks
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var durationWeeks: Int { weeks.count }

    public var orderedWeeks: [ProgramWeek] {
        weeks.sorted { $0.index < $1.index }
    }

    public var totalTrainingDays: Int {
        weeks.reduce(0) { $0 + $1.days.count }
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Program name must not be empty.")
        }

        let weekIndexes = weeks.map(\.index)
        if Set(weekIndexes).count != weekIndexes.count {
            issues.append("Program contains duplicate week indexes.")
        }

        for week in weeks {
            issues.append(contentsOf: week.validationIssues().map { "Week \(week.index): \($0)" })
        }

        return issues
    }

    public static func makeSlug(_ input: String) -> String {
        let lowered = input.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "- "))
        let filtered = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let cleaned = String(filtered)
            .replacingOccurrences(of: " ", with: "-")
        // collapse multiple dashes
        return cleaned
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

// MARK: - Resilient decoding (generates ids/slug if missing)
extension TrainingProgram {
    private enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, author, level, tags, equipment, weeks, source, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? c.decode(String.self, forKey: .name)) ?? "Untitled Program"
        let rawSlug = (try? c.decode(String.self, forKey: .slug))
        self.slug = TrainingProgram.makeSlug((rawSlug?.isEmpty == false) ? rawSlug! : self.name)

        self.summary = try? c.decode(String.self, forKey: .summary)
        self.author = try? c.decode(String.self, forKey: .author)
        self.level = (try? c.decode(Level.self, forKey: .level)) ?? .unknown
        self.tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        self.equipment = (try? c.decode([String].self, forKey: .equipment)) ?? []
        self.weeks = (try? c.decode([ProgramWeek].self, forKey: .weeks)) ?? []
        self.source = (try? c.decode(ProgramSource.self, forKey: .source)) ?? .custom
        self.createdAt = try? c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try? c.decode(Date.self, forKey: .updatedAt)
    }
}
