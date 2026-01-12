import Foundation
import SwiftData

enum WorkoutSessionStatus: String, Codable {
    case inProgress
    case completed
    case abandoned
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID

    var startedAt: Date
    var endedAt: Date?

    var sourceRoutineId: UUID?
    var sourceRoutineNameSnapshot: String?
    var linkedActivityId: UUID?

    var statusRaw: String

    // ✅ Timer pause support
    var isPaused: Bool
    var pausedAt: Date?
    var accumulatedPausedSeconds: Int

    // ✅ Parent -> children (cascade), no inverse
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutSessionExercise] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        sourceRoutineId: UUID? = nil,
        sourceRoutineNameSnapshot: String? = nil,
        linkedActivityId: UUID? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.sourceRoutineId = sourceRoutineId
        self.sourceRoutineNameSnapshot = sourceRoutineNameSnapshot
        self.linkedActivityId = linkedActivityId
        self.statusRaw = WorkoutSessionStatus.inProgress.rawValue

        self.isPaused = false
        self.pausedAt = nil
        self.accumulatedPausedSeconds = 0
    }

    var status: WorkoutSessionStatus {
        get { WorkoutSessionStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    func pause(at now: Date = Date()) {
        guard !isPaused else { return }
        isPaused = true
        pausedAt = now
    }

    func resume(at now: Date = Date()) {
        guard isPaused, let pausedAt else { return }
        accumulatedPausedSeconds += max(0, Int(now.timeIntervalSince(pausedAt)))
        isPaused = false
        self.pausedAt = nil
    }

    func elapsedSeconds(at now: Date = Date()) -> Int {
        let end = endedAt ?? now
        var total = Int(end.timeIntervalSince(startedAt)) - accumulatedPausedSeconds
        if isPaused, let pausedAt {
            total -= max(0, Int(end.timeIntervalSince(pausedAt)))
        }
        return max(0, total)
    }
}
