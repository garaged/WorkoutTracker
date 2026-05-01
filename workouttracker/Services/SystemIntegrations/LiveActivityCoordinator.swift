import Foundation
import ActivityKit

@available(iOS 16.1, *)
@MainActor
final class LiveActivityCoordinator {
    typealias WorkoutActivity = ActivityKit.Activity<ActiveWorkoutActivityAttributes>
    typealias WorkoutContent = ActivityKit.ActivityContent<ActiveWorkoutActivityAttributes.ContentState>

    private struct ActivityFingerprint: Equatable {
        let sessionID: UUID?
        let sessionTitle: String?
        let currentExerciseName: String?
        let currentSetIndex: Int?
        let totalSets: Int?
        let restModeDescription: String?
        let restReferenceDate: Date?
        let openURLString: String?
    }

    private static var lastFingerprint: ActivityFingerprint?
    private static var scheduledOverdueRefresh: ScheduledOverdueRefresh?

    private struct ScheduledOverdueRefresh: Equatable {
        let sessionID: UUID
        let restReferenceDate: Date
        let task: Task<Void, Never>

        static func == (lhs: ScheduledOverdueRefresh, rhs: ScheduledOverdueRefresh) -> Bool {
            lhs.sessionID == rhs.sessionID && lhs.restReferenceDate == rhs.restReferenceDate
        }
    }

    private let mapper: LiveActivityStateMapper

    init(mapper: LiveActivityStateMapper = LiveActivityStateMapper()) {
        self.mapper = mapper
    }

    func sync(using snapshot: WidgetExternalSnapshot) async {
        let mapped = mapper.map(snapshot: snapshot)
        let targetSessionID = mapped?.sessionID
        let fingerprint = activityFingerprint(for: mapped)

        scheduleOverdueRefresh(for: mapped)

        if targetSessionID == nil,
           WorkoutActivity.activities.isEmpty,
           Self.lastFingerprint == fingerprint {
            return
        }

        await endActivities(except: targetSessionID)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            if targetSessionID == nil {
                await endAll()
            }
            Self.lastFingerprint = fingerprint
            return
        }

        guard let mapped else {
            await endAll()
            Self.lastFingerprint = fingerprint
            return
        }

        if Self.lastFingerprint == fingerprint,
           WorkoutActivity.activities.contains(where: { $0.attributes.sessionID == mapped.sessionID }) {
            return
        }

        let content = WorkoutContent(
            state: mapped.contentState,
            staleDate: mapped.staleDate
        )

        if let existing = WorkoutActivity.activities.first(where: { $0.attributes.sessionID == mapped.sessionID }) {
            if existing.attributes.sessionTitle != mapped.attributes.sessionTitle {
                await existing.end(
                    nil as WorkoutContent?,
                    dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
                )
                await requestActivity(attributes: mapped.attributes, content: content)
                Self.lastFingerprint = fingerprint
                return
            }

            await existing.update(content)
            Self.lastFingerprint = fingerprint
            return
        }

        await requestActivity(attributes: mapped.attributes, content: content)
        Self.lastFingerprint = fingerprint
    }

    private func activityFingerprint(for mapped: LiveActivityStateMapper.MappedState?) -> ActivityFingerprint {
        guard let mapped else {
            return ActivityFingerprint(
                sessionID: nil,
                sessionTitle: nil,
                currentExerciseName: nil,
                currentSetIndex: nil,
                totalSets: nil,
                restModeDescription: nil,
                restReferenceDate: nil,
                openURLString: nil
            )
        }

        return ActivityFingerprint(
            sessionID: mapped.sessionID,
            sessionTitle: mapped.attributes.sessionTitle,
            currentExerciseName: mapped.contentState.currentExerciseName,
            currentSetIndex: mapped.contentState.currentSetIndex,
            totalSets: mapped.contentState.totalSets,
            restModeDescription: String(describing: mapped.contentState.restMode),
            restReferenceDate: mapped.contentState.restReferenceDate,
            openURLString: mapped.contentState.openURLString
        )
    }

    func endAll() async {
        cancelScheduledOverdueRefresh()
        for activity in WorkoutActivity.activities {
            await activity.end(
                nil as WorkoutContent?,
                dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
            )
        }
    }

    func end(sessionID: UUID) async {
        if Self.scheduledOverdueRefresh?.sessionID == sessionID {
            cancelScheduledOverdueRefresh()
        }
        for activity in WorkoutActivity.activities where activity.attributes.sessionID == sessionID {
            await activity.end(
                nil as WorkoutContent?,
                dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
            )
        }
    }

    private func requestActivity(
        attributes: ActiveWorkoutActivityAttributes,
        content: WorkoutContent
    ) async {
        do {
            _ = try WorkoutActivity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity request failed: \(error)")
            #endif
        }
    }

    private func endActivities(except sessionID: UUID?) async {
        for activity in WorkoutActivity.activities {
            guard activity.attributes.sessionID != sessionID else { continue }
            if Self.scheduledOverdueRefresh?.sessionID == activity.attributes.sessionID {
                cancelScheduledOverdueRefresh()
            }
            await activity.end(
                nil as WorkoutContent?,
                dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
            )
        }
    }

    private func scheduleOverdueRefresh(for mapped: LiveActivityStateMapper.MappedState?) {
        guard let mapped,
              mapped.contentState.restMode == .running,
              let restReferenceDate = mapped.contentState.restReferenceDate else {
            cancelScheduledOverdueRefresh()
            return
        }

        if let existing = Self.scheduledOverdueRefresh,
           existing.sessionID == mapped.sessionID,
           existing.restReferenceDate == restReferenceDate {
            return
        }

        cancelScheduledOverdueRefresh()

        let delay = max(0, restReferenceDate.timeIntervalSinceNow) + 0.2
        let sessionID = mapped.sessionID
        let contentState = mapped.contentState
        let staleDate = mapped.staleDate

        let task = Task { @MainActor in
            let sleepNanos = UInt64(max(0, delay) * 1_000_000_000)
            if sleepNanos > 0 {
                try? await Task.sleep(nanoseconds: sleepNanos)
            }

            guard !Task.isCancelled,
                  Self.scheduledOverdueRefresh?.sessionID == sessionID,
                  Self.scheduledOverdueRefresh?.restReferenceDate == restReferenceDate,
                  let activity = WorkoutActivity.activities.first(where: { $0.attributes.sessionID == sessionID }) else {
                return
            }

            let overdueState = ActiveWorkoutActivityAttributes.ContentState(
                currentExerciseName: contentState.currentExerciseName,
                currentSetIndex: contentState.currentSetIndex,
                totalSets: contentState.totalSets,
                stateGeneratedAt: Date(),
                sessionStartDate: contentState.sessionStartDate,
                restMode: .overdue,
                restReferenceDate: contentState.restReferenceDate,
                openURLString: contentState.openURLString
            )

            await activity.update(
                WorkoutContent(
                    state: overdueState,
                    staleDate: staleDate
                )
            )

            Self.lastFingerprint = ActivityFingerprint(
                sessionID: sessionID,
                sessionTitle: activity.attributes.sessionTitle,
                currentExerciseName: overdueState.currentExerciseName,
                currentSetIndex: overdueState.currentSetIndex,
                totalSets: overdueState.totalSets,
                restModeDescription: String(describing: overdueState.restMode),
                restReferenceDate: overdueState.restReferenceDate,
                openURLString: overdueState.openURLString
            )
            Self.scheduledOverdueRefresh = nil
        }

        Self.scheduledOverdueRefresh = ScheduledOverdueRefresh(
            sessionID: mapped.sessionID,
            restReferenceDate: restReferenceDate,
            task: task
        )
    }

    private func cancelScheduledOverdueRefresh() {
        Self.scheduledOverdueRefresh?.task.cancel()
        Self.scheduledOverdueRefresh = nil
    }
}
