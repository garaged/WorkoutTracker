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

    private let mapper: LiveActivityStateMapper

    init(mapper: LiveActivityStateMapper = LiveActivityStateMapper()) {
        self.mapper = mapper
    }

    func sync(using snapshot: WidgetExternalSnapshot) async {
        let mapped = mapper.map(snapshot: snapshot)
        let targetSessionID = mapped?.sessionID
        let fingerprint = activityFingerprint(for: mapped)

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
        for activity in WorkoutActivity.activities {
            await activity.end(
                nil as WorkoutContent?,
                dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
            )
        }
    }

    func end(sessionID: UUID) async {
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
            await activity.end(
                nil as WorkoutContent?,
                dismissalPolicy: ActivityKit.ActivityUIDismissalPolicy.immediate
            )
        }
    }
}
