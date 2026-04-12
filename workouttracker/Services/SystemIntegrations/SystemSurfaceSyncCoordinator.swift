import Foundation
import SwiftData

@MainActor
struct SystemSurfaceSyncCoordinator {
    private struct LiveActivityFingerprint: Equatable {
        let sessionID: UUID?
        let title: String?
        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let restStateDescription: String?
        let restSeconds: Int?
        let isResumable: Bool
        let isFinishable: Bool
        let openRouteURL: String?
        let resumeRouteURL: String?
        let restRouteURL: String?
    }

    private static var lastLiveActivityFingerprint: LiveActivityFingerprint?

    private let snapshotBuilder: CurrentSessionSnapshotBuilder
    private let widgetRefreshCoordinator: WidgetRefreshCoordinator

    init(
        snapshotBuilder: CurrentSessionSnapshotBuilder,
        widgetRefreshCoordinator: WidgetRefreshCoordinator
    ) {
        self.snapshotBuilder = snapshotBuilder
        self.widgetRefreshCoordinator = widgetRefreshCoordinator
    }

    init() {
        self.snapshotBuilder = CurrentSessionSnapshotBuilder()
        self.widgetRefreshCoordinator = WidgetRefreshCoordinator()
    }

    func syncAll(context: ModelContext) {
        widgetRefreshCoordinator.refresh(context: context)
        syncLiveActivity(context: context, force: false)
    }

    func syncActiveSessionSurfaces(context: ModelContext) {
        widgetRefreshCoordinator.refreshActiveSession(context: context)
        syncLiveActivity(context: context, force: false)
    }

    func syncLiveActivity(context: ModelContext, force: Bool) {
        guard #available(iOS 16.1, *) else { return }

        let snapshot = snapshotBuilder.buildWidgetActiveSessionSnapshot(
            context: context,
            preservedCurrentStreakDays: 0,
            preservedLongestStreakDays: 0,
            preservedWorkoutsThisWeek: 0
        )

        let fingerprint = liveActivityFingerprint(for: snapshot.activeSession)

        if !force, Self.lastLiveActivityFingerprint == fingerprint {
            return
        }

        Self.lastLiveActivityFingerprint = fingerprint

        Task { @MainActor in
            await LiveActivityCoordinator().sync(using: snapshot)
        }
    }

    private func liveActivityFingerprint(
        for activeSession: WidgetExternalSnapshot.ActiveSession?
    ) -> LiveActivityFingerprint {
        LiveActivityFingerprint(
            sessionID: activeSession?.sessionID,
            title: activeSession?.title,
            currentExerciseName: activeSession?.currentExerciseName,
            currentSetIndex: activeSession?.currentSetIndex,
            totalSets: activeSession?.totalSets,
            restStateDescription: activeSession.map { String(describing: $0.restState) },
            restSeconds: activeSession?.restSeconds,
            isResumable: activeSession?.isResumable ?? false,
            isFinishable: activeSession?.isFinishable ?? false,
            openRouteURL: activeSession?.openRouteURL,
            resumeRouteURL: activeSession?.resumeRouteURL,
            restRouteURL: activeSession?.restRouteURL
        )
    }
}
