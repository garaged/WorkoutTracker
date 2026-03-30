import WidgetKit
import SwiftUI

@main
struct WorkoutTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ActiveSessionWidget()
        StreakWidget()
        if #available(iOS 16.1, *) {
            ActiveWorkoutLiveActivity()
        }
    }
}
