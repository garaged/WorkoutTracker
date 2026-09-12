import Foundation
import SwiftData

@MainActor
struct QuickStartRecorder {
    enum RecordingError: Error, Equatable {
        case pendingChanges
        case activeSessionConflict([UUID])
        case identityConflict
        case invalidRecord
    }

    var save: (ModelContext) throws -> Void = { try $0.save() }

    func start(style: QuickStartStyle, id: UUID, at clock: QuickStartClockSample,
               context: ModelContext) throws -> TrackedActivitySession {
        TrackedActivitySession(id: id, activityKind: .generic)
    }

    func apply(_ action: QuickStartTimingState.Action, to session: TrackedActivitySession,
               id: UUID, expectedRevision: Int, at clock: QuickStartClockSample,
               context: ModelContext) throws {
    }
}
