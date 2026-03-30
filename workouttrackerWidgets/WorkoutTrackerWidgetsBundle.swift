import WidgetKit
import SwiftUI

@main
struct WorkoutTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ActiveSessionWidget()
        StreakWidget()
    }
}
