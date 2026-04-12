import Foundation
import SwiftData

enum TrackedActivityHealthExportTrigger {
    case automatic
    case manual
}

@MainActor
struct TrackedActivityHealthExportCoordinator {
    private let recorder: TrackedActivityRecorder
    private let exportService: HealthKitWorkoutExportService

    init() {
        self.init(
            recorder: TrackedActivityRecorder(),
            exportService: HealthKitWorkoutExportService()
        )
    }

    init(
        recorder: TrackedActivityRecorder,
        exportService: HealthKitWorkoutExportService
    ) {
        self.recorder = recorder
        self.exportService = exportService
    }

    @MainActor
    private enum TrackedActivityHealthExportInFlight {
        static var sessionIDs: Set<UUID> = []
    }

    func autoExportIfEnabled(
        for session: TrackedActivitySession,
        isEnabled: Bool,
        context: ModelContext
    ) async throws -> String? {
        guard isEnabled else { return nil }
        guard session.lifecycleState == .completed else { return nil }
        guard session.healthKitExportState != .pending else { return nil }
        guard session.healthKitExportState != .exported else { return nil }
        guard !TrackedActivityHealthExportInFlight.sessionIDs.contains(session.id) else { return nil }

        return try await export(session, trigger: .automatic, context: context)
    }

    func export(
        _ session: TrackedActivitySession,
        trigger: TrackedActivityHealthExportTrigger,
        context: ModelContext
    ) async throws -> String {
        guard !TrackedActivityHealthExportInFlight.sessionIDs.contains(session.id) else {
            return successMessage(for: session, routeStatus: .notApplicable, trigger: trigger)
        }

        TrackedActivityHealthExportInFlight.sessionIDs.insert(session.id)
        defer { TrackedActivityHealthExportInFlight.sessionIDs.remove(session.id) }

        let payload = TrackedActivityHealthExportPayload.make(from: session)

        try recorder.updateHealthKitExportState(for: session, state: .pending, context: context)

        do {
            let outcome = try await exportService.export(payload)

            try recorder.updateHealthKitExportState(for: session, state: .exported, context: context)

            let routeUpdateDate = Date()
            switch outcome.routeExportStatus {
            case .saved:
                session.markHealthKitRouteAttachment(state: .attached, at: routeUpdateDate)
            case .notApplicable:
                session.markHealthKitRouteAttachment(state: .notApplicable, at: routeUpdateDate)
            case .noRouteData:
                session.markHealthKitRouteAttachment(state: .noRouteData, at: routeUpdateDate)
            case .failed(let reason):
                let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                session.markHealthKitRouteAttachment(
                    state: .failed,
                    message: cleanReason.isEmpty ? nil : cleanReason,
                    at: routeUpdateDate
                )
            }

            try? context.save()

            return successMessage(for: session, routeStatus: outcome.routeExportStatus, trigger: trigger)
        } catch let exportError as HealthKitWorkoutExportError {
            let failedState: HealthKitExportState = {
                switch exportError {
                case .healthDataUnavailable:
                    return .notAvailable
                case .permissionDenied,
                     .sessionMustBeCompleted,
                     .sessionDatesUnavailable,
                     .unsupportedActivity:
                    return .failed
                }
            }()

            try? recorder.updateHealthKitExportState(
                for: session,
                state: failedState,
                context: context,
                failureMessage: exportError.localizedDescription
            )
            throw exportError
        } catch {
            try? recorder.updateHealthKitExportState(
                for: session,
                state: .failed,
                context: context,
                failureMessage: error.localizedDescription
            )
            throw error
        }
    }

    private func successMessage(
        for session: TrackedActivitySession,
        routeStatus: HealthKitWorkoutRouteExportStatus,
        trigger: TrackedActivityHealthExportTrigger
    ) -> String {
        let prefix = trigger == .automatic
            ? "Saved automatically to Apple Health."
            : "Saved to Apple Health."

        switch routeStatus {
        case .saved:
            return trigger == .automatic
                ? "Saved automatically to Apple Health with your outdoor route."
                : "Saved to Apple Health with your outdoor route."

        case .notApplicable:
            return prefix

        case .noRouteData:
            if session.environment == .outdoor && session.activityKind.supportsDistance {
                return "\(prefix) Route data was not available to attach."
            }
            return prefix

        case .failed(let reason):
            if session.environment == .outdoor && session.activityKind.supportsDistance {
                let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanReason.isEmpty {
                    return "\(prefix) The workout was exported, but the outdoor route could not be attached."
                }
                return "\(prefix) The workout was exported, but the outdoor route could not be attached. \(cleanReason)"
            }
            return prefix
        }
    }
}
