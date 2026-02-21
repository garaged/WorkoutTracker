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

    // Timer pause support
    var isPaused: Bool
    var pausedAt: Date?
    var accumulatedPausedSeconds: Int

    // ✅ Explicit inverse breaks SwiftData macro cycles
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutSessionExercise]
    
    // MARK: - Session Reflection (optional / post-session)

    /// Optional “how did it go” mood.
    /// Keep optional so it never blocks the logging flow.
    var reflectionMood: SessionReflectionMood?

    /// Optional free-form note (trimmed on save).
    var reflectionNote: String?

    /// Set when the reflection is first saved (not updated on edits).
    var reflectionCreatedAt: Date?
    
    // MARK: model

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
        self.exercises = []
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

    /// Reopens a finished/abandoned session so the user can continue logging without losing data.
    func reopenForContinuation() {
        if isPaused { resume() }
        endedAt = nil
        status = .inProgress
    }
}

// Makes `.sheet(item:)` happy in other screens
extension WorkoutSession: Identifiable {}
