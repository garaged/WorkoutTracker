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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let mapped = mapper.map(snapshot: snapshot) else {
            await endAll()
            return
        }

        let content = WorkoutContent(
            state: mapped.contentState,
            staleDate: nil
        )

        if let existing = WorkoutActivity.activities.first(where: { $0.attributes.sessionID == mapped.sessionID }) {
            await existing.update(content)
            return
        }

        do {
            _ = try WorkoutActivity.request(
                attributes: mapped.attributes,
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity request failed: \(error)")
            #endif
        }
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
}
