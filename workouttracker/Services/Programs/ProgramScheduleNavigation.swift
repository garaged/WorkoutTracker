// workouttracker/Services/Programs/ProgramScheduleNavigation.swift
import Foundation
import SwiftUI

extension Notification.Name {
    static let openTimelineForDate = Notification.Name("workouttracker.openTimelineForDate")
}

/// Hook Programs can call to request "open day on this date".
/// Default behavior: posts a Notification that any screen can observe.
private struct OpenTimelineForDateActionKey: EnvironmentKey {
    static let defaultValue: (Date) -> Void = { date in
        NotificationCenter.default.post(name: .openTimelineForDate, object: date)
    }
}

extension EnvironmentValues {
    var openTimelineForDate: (Date) -> Void {
        get { self[OpenTimelineForDateActionKey.self] }
        set { self[OpenTimelineForDateActionKey.self] = newValue }
    }
}
