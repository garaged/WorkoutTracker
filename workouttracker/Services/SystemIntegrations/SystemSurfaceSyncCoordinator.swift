import Foundation
import SwiftData

@MainActor
struct SystemSurfaceSyncCoordinator {
    private struct LiveActivityFingerprint: Equatable {
        let sessionID: UUID?
        let sessionTitle: String?
        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let restState: CurrentSessionSnapshot.RestState
        let restSeconds: Int?
        let isResumable: Bool
        let isFinishable: Bool
        let openRoute: String?
        let resumeRoute: String?
        let restRoute: String?
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
        self.init(
            snapshotBuilder: CurrentSessionSnapshotBuilder(),
            widgetRefreshCoordinator: WidgetRefreshCoordinator()
        )
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

        let currentSession = snapshotBuilder.build(context: context)
        let fingerprint = liveActivityFingerprint(for: currentSession)

        if !force, Self.lastLiveActivityFingerprint == fingerprint {
            return
        }

        let snapshot = snapshotBuilder.buildActiveSessionSurfaceSnapshot(
            context: context,
            preservedCurrentStreakDays: 0,
            preservedLongestStreakDays: 0,
            preservedWorkoutsThisWeek: 0
        )
        Self.lastLiveActivityFingerprint = fingerprint

        Task { @MainActor in
            await LiveActivityCoordinator().sync(using: snapshot)
        }
    }

    private func liveActivityFingerprint(for snapshot: CurrentSessionSnapshot) -> LiveActivityFingerprint {
        LiveActivityFingerprint(
            sessionID: snapshot.sessionID,
            sessionTitle: snapshot.sessionTitle,
            currentExerciseName: snapshot.currentExerciseName,
            currentSetIndex: snapshot.currentSetIndex,
            totalSets: snapshot.totalSets,
            restState: snapshot.restState,
            restSeconds: snapshot.restSeconds,
            isResumable: snapshot.isResumable,
            isFinishable: snapshot.isFinishable,
            openRoute: snapshot.openRoute.map(String.init(describing:)),
            resumeRoute: snapshot.resumeRoute.map(String.init(describing:)),
            restRoute: snapshot.restRoute.map(String.init(describing:))
        )
    }
}
