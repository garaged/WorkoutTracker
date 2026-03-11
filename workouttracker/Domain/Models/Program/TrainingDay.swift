import Foundation

public struct TrainingDay: Identifiable, Codable, Hashable, Sendable {
    public struct TrainingBlock: Identifiable, Codable, Hashable, Sendable {
        public enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
            case workout
            case accessories
            case cardio
            case mobility
            case rest
            case notes
        }

        public struct Reference: Codable, Hashable, Sendable {
            public enum RefKind: String, Codable, CaseIterable, Hashable, Sendable {
                /// Later: link to your WorkoutRoutine entity (UUID in your store)
                case routine
                /// Later: link to a template activity (UUID in your store)
                case templateActivity
                /// A generic placeholder for future mapping (URL, slug, etc.)
                case external
            }

            public var kind: RefKind
            public var id: UUID?
            public var slug: String?
            public var url: URL?

            public init(kind: RefKind, id: UUID? = nil, slug: String? = nil, url: URL? = nil) {
                self.kind = kind
                self.id = id
                self.slug = slug
                self.url = url
            }
        }

        public var id: UUID
        public var kind: Kind
        public var title: String
        public var estimatedMinutes: Int?
        public var notes: String?
        public var reference: Reference?

        public init(
            id: UUID = UUID(),
            kind: Kind,
            title: String,
            estimatedMinutes: Int? = nil,
            notes: String? = nil,
            reference: Reference? = nil
        ) {
            self.id = id
            self.kind = kind
            self.title = title
            self.estimatedMinutes = estimatedMinutes
            self.notes = notes
            self.reference = reference
        }
    }

    public var id: UUID
    /// 1...7 convention (Mon..Sun or Day 1..Day 7 depending on your UI choice)
    public var index: Int
    public var title: String
    public var focus: String?
    public var blocks: [TrainingBlock]

    public init(
        id: UUID = UUID(),
        index: Int,
        title: String,
        focus: String? = nil,
        blocks: [TrainingBlock] = []
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.focus = focus
        self.blocks = blocks
    }
}

// MARK: - Resilient decoding (generates ids if missing)
extension TrainingDay {
    private enum CodingKeys: String, CodingKey {
        case id, index, title, focus, blocks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.index = (try? c.decode(Int.self, forKey: .index)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Day \(self.index)"
        self.focus = try? c.decode(String.self, forKey: .focus)
        self.blocks = (try? c.decode([TrainingBlock].self, forKey: .blocks)) ?? []
    }
}

extension TrainingDay.TrainingBlock {
    private enum CodingKeys: String, CodingKey {
        case id, kind, title, estimatedMinutes, notes, reference
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .workout
        self.title = (try? c.decode(String.self, forKey: .title)) ?? ""
        self.estimatedMinutes = try? c.decode(Int.self, forKey: .estimatedMinutes)
        self.notes = try? c.decode(String.self, forKey: .notes)
        self.reference = try? c.decode(Reference.self, forKey: .reference)
    }
}
