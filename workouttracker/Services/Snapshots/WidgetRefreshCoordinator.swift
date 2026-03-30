import Foundation
import SwiftData
import WidgetKit

@MainActor
struct WidgetRefreshCoordinator {
    static let activeSessionWidgetKind = "ActiveSessionWidget"
    static let streakWidgetKind = "StreakWidget"

    private let snapshotBuilder: CurrentSessionSnapshotBuilder
    private let snapshotStore: WidgetSnapshotStore

    init(
        snapshotBuilder: CurrentSessionSnapshotBuilder = CurrentSessionSnapshotBuilder(),
        snapshotStore: WidgetSnapshotStore = WidgetSnapshotStore()
    ) {
        self.snapshotBuilder = snapshotBuilder
        self.snapshotStore = snapshotStore
    }

    func refresh(context: ModelContext) {
        guard ProcessInfo.processInfo.environment["UITESTS"] != "1" else { return }

        let snapshot = snapshotBuilder.buildWidgetSnapshot(context: context)
        do {
            try snapshotStore.save(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.activeSessionWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: Self.streakWidgetKind)
        } catch {
            assertionFailure("Failed to refresh widget snapshots: \(error)")
        }
    }
}
