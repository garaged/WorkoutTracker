import Foundation

public struct ProgramDay: Identifiable, Codable, Hashable, Sendable {
    public struct Block: Identifiable, Codable, Hashable, Sendable {
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
                case routine
                case templateActivity
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

    public typealias TrainingBlock = Block

    public var id: UUID
    public var index: Int
    public var title: String
    public var focus: String?
    public var kind: ProgramDayKind
    public var blocks: [Block]
    public var prescriptions: [ProgramPrescription]

    public init(
        id: UUID = UUID(),
        index: Int,
        title: String,
        focus: String? = nil,
        kind: ProgramDayKind = .training,
        blocks: [Block] = [],
        prescriptions: [ProgramPrescription] = []
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.focus = focus
        self.kind = kind
        self.blocks = blocks
        self.prescriptions = prescriptions
    }

    public var orderedPrescriptions: [ProgramPrescription] {
        prescriptions.sorted { $0.order < $1.order }
    }

    public var primaryRoutineReference: Block.Reference? {
        blocks.first(where: { $0.reference?.kind == .routine })?.reference
    }

    public var isRestLikeDay: Bool {
        kind == .rest || (!blocks.isEmpty && blocks.allSatisfy { $0.kind == .rest })
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Day title must not be empty.")
        }

        let prescriptionOrders = prescriptions.map(\.order)
        if Set(prescriptionOrders).count != prescriptionOrders.count {
            issues.append("Duplicate prescription order values.")
        }

        return issues
    }
}

extension ProgramDay {
    private enum CodingKeys: String, CodingKey {
        case id
        case index
        case title
        case focus
        case kind
        case blocks
        case prescriptions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.index = (try? c.decode(Int.self, forKey: .index)) ?? 1
        self.title = (try? c.decode(String.self, forKey: .title)) ?? "Day \(self.index)"
        self.focus = try? c.decode(String.self, forKey: .focus)
        self.kind = (try? c.decode(ProgramDayKind.self, forKey: .kind)) ?? .training
        self.blocks = (try? c.decode([Block].self, forKey: .blocks)) ?? []
        self.prescriptions = (try? c.decode([ProgramPrescription].self, forKey: .prescriptions)) ?? []
    }
}

extension ProgramDay.Block {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case estimatedMinutes
        case notes
        case reference
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
