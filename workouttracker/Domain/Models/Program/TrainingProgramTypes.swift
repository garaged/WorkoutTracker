import Foundation

public enum ProgramSource: String, Codable, CaseIterable, Hashable, Sendable {
    case bundled
    case imported
    case custom
}

enum ProgramAssignmentStatus: String, Codable, CaseIterable {
    case active
    case paused
    case completed
}

enum ProgramScheduleAnchorStrategy: String, Codable, CaseIterable {
    case calendarAligned
    case sequential
}

public enum ProgramDayKind: String, Codable, CaseIterable, Hashable, Sendable {
    case training
    case rest
    case recovery
}

enum ProgramCompletedDaySource: String, Codable, CaseIterable {
    case workoutSession
    case manual
}

enum ProgramMissedDayReason: String, Codable, CaseIterable {
    case skipped
    case deferred
    case unknown
}
