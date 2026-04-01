import Foundation
import ActivityKit

@available(iOS 16.1, *)
@MainActor
final class LiveActivityCoordinator {
    typealias WorkoutActivity = ActivityKit.Activity<ActiveWorkoutActivityAttributes>
    typealias WorkoutContent = ActivityKit.ActivityContent<ActiveWorkoutActivityAttributes.ContentState>

    private let mapper: LiveActivityStateMapper

    init(mapper: LiveActivityStateMapper = LiveActivityStateMapper()) {
        self.mapper = mapper
    }

    func sync(using snapshot: WidgetExternalSnapshot) async {
        let mapped = mapper.map(snapshot: snapshot)
        let targetSessionID = mapped?.sessionID

        await endActivities(except: targetSessionID)

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            if targetSessionID == nil {
                await endAll()
            }
            return
        }

        guard let mapped else {
            await endAll()
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
                return
            }

            await existing.update(content)
            return
        }

        await requestActivity(attributes: mapped.attributes, content: content)
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
