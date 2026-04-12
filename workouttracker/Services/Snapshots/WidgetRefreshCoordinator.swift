import Foundation
import SwiftData
import WidgetKit

@MainActor
struct WidgetRefreshCoordinator {
    static let activeSessionWidgetKind = "ActiveSessionWidget"
    static let streakWidgetKind = "StreakWidget"

    private struct ActiveSessionFingerprint: Equatable {
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

    private struct FullSnapshotFingerprint: Equatable {
        let activeSession: ActiveSessionFingerprint
        let currentStreakDays: Int
        let longestStreakDays: Int
        let workoutsThisWeek: Int
        let schemaVersionDescription: String
    }

    private static var lastActiveSessionFingerprint: ActiveSessionFingerprint?
    private static var lastFullSnapshotFingerprint: FullSnapshotFingerprint?

    private let snapshotBuilder: CurrentSessionSnapshotBuilder
    private let snapshotStore: WidgetSnapshotStore

    init(
        snapshotBuilder: CurrentSessionSnapshotBuilder,
        snapshotStore: WidgetSnapshotStore
    ) {
        self.snapshotBuilder = snapshotBuilder
        self.snapshotStore = snapshotStore
    }

    init() {
        self.snapshotBuilder = CurrentSessionSnapshotBuilder()
        self.snapshotStore = WidgetSnapshotStore()
    }

    func refresh(context: ModelContext) {
        guard ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }

        let snapshot = snapshotBuilder.buildWidgetSnapshot(context: context)
        let fingerprint = fullSnapshotFingerprint(for: snapshot)

        if Self.lastFullSnapshotFingerprint == fingerprint {
            return
        }

        if let existing = snapshotStore.load(), fullSnapshotFingerprint(for: existing) == fingerprint {
            Self.lastFullSnapshotFingerprint = fingerprint
            Self.lastActiveSessionFingerprint = activeSessionFingerprint(for: snapshot)
            return
        }

        do {
            try snapshotStore.save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.activeSessionWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.streakWidgetKind)
            Self.lastFullSnapshotFingerprint = fingerprint
            Self.lastActiveSessionFingerprint = activeSessionFingerprint(for: snapshot)
        } catch {
            assertionFailure("Failed to refresh widget snapshots: \(error)")
        }
    }

    func refreshActiveSession(context: ModelContext) {
        guard ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }

        let existingSnapshot = snapshotStore.load()
        let snapshot = snapshotBuilder.buildWidgetActiveSessionSnapshot(
            context: context,
            preservedCurrentStreakDays: existingSnapshot?.streak.currentStreakDays ?? 0,
            preservedLongestStreakDays: existingSnapshot?.streak.longestStreakDays ?? 0,
            preservedWorkoutsThisWeek: existingSnapshot?.streak.workoutsThisWeek ?? 0
        )
        let fingerprint = activeSessionFingerprint(for: snapshot)

        if Self.lastActiveSessionFingerprint == fingerprint {
            return
        }

        if let existingSnapshot, activeSessionFingerprint(for: existingSnapshot) == fingerprint {
            Self.lastActiveSessionFingerprint = fingerprint
            return
        }

        do {
            try snapshotStore.save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.activeSessionWidgetKind)
            Self.lastActiveSessionFingerprint = fingerprint
            Self.lastFullSnapshotFingerprint = existingSnapshot.map(fullSnapshotFingerprint)
        } catch {
            assertionFailure("Failed to refresh active-session widget snapshot: \(error)")
        }
    }

    private func activeSessionFingerprint(for snapshot: WidgetExternalSnapshot) -> ActiveSessionFingerprint {
        let activeSession = snapshot.activeSession
        return ActiveSessionFingerprint(
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

    private func fullSnapshotFingerprint(for snapshot: WidgetExternalSnapshot) -> FullSnapshotFingerprint {
        FullSnapshotFingerprint(
            activeSession: activeSessionFingerprint(for: snapshot),
            currentStreakDays: snapshot.streak.currentStreakDays,
            longestStreakDays: snapshot.streak.longestStreakDays,
            workoutsThisWeek: snapshot.streak.workoutsThisWeek,
            schemaVersionDescription: String(describing: snapshot.schemaVersion)
        )
    }
}
