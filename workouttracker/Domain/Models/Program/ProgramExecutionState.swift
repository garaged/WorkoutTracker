import Foundation
import SwiftData

@Model
final class ProgramExecutionState {
    @Attribute(.unique) var id: UUID

    var currentWeekIndex: Int
    var currentDayIndex: Int?
    var lastEvaluatedAt: Date?

    @Attribute(.externalStorage) private var repeatedWeekIndexesData: Data
    @Attribute(.externalStorage) private var deloadedWeekIndexesData: Data

    var assignment: ProgramAssignment?

    @Relationship(deleteRule: .cascade, inverse: \ProgramCompletedDay.executionState)
    var completedDays: [ProgramCompletedDay] = []

    @Relationship(deleteRule: .cascade, inverse: \ProgramMissedDay.executionState)
    var missedDays: [ProgramMissedDay] = []

    init(
        id: UUID = UUID(),
        currentWeekIndex: Int = 1,
        currentDayIndex: Int? = 1,
        lastEvaluatedAt: Date? = nil,
        repeatedWeekIndexes: [Int] = [],
        deloadedWeekIndexes: [Int] = []
    ) {
        self.id = id
        self.currentWeekIndex = currentWeekIndex
        self.currentDayIndex = currentDayIndex
        self.lastEvaluatedAt = lastEvaluatedAt
        self.repeatedWeekIndexesData = Self.encodeIndexes(repeatedWeekIndexes)
        self.deloadedWeekIndexesData = Self.encodeIndexes(deloadedWeekIndexes)
    }

    var repeatedWeekIndexes: [Int] {
        get { Self.decodeIndexes(repeatedWeekIndexesData) }
        set { repeatedWeekIndexesData = Self.encodeIndexes(newValue) }
    }

    var deloadedWeekIndexes: [Int] {
        get { Self.decodeIndexes(deloadedWeekIndexesData) }
        set { deloadedWeekIndexesData = Self.encodeIndexes(newValue) }
    }

    private static func encodeIndexes(_ indexes: [Int]) -> Data {
        (try? JSONEncoder().encode(indexes.sorted())) ?? Data()
    }

    private static func decodeIndexes(_ data: Data) -> [Int] {
        (try? JSONDecoder().decode([Int].self, from: data)) ?? []
    }
}
