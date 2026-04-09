import Foundation

struct WatchPresentationEvaluator {
    enum TrackedControlsPrimaryAction: Equatable {
        case resume
        case pause
    }

    enum FooterStyle: Equatable {
        case reconnecting
        case currentActivity
        case restTimer
    }

    enum CurrentActivityPrimaryAction: Equatable {
        case resumeActivity
        case openCurrentActivity
    }

    enum CurrentActivityControlsAction: Equatable {
        case reconnectControls
        case openControls
    }

    func trackedControlsPrimaryAction(isPaused: Bool) -> TrackedControlsPrimaryAction {
        isPaused ? .resume : .pause
    }

    func footerStyle(isTrackedActivitySession: Bool, isRecoveringRecentSession: Bool) -> FooterStyle {
        if isTrackedActivitySession {
            return isRecoveringRecentSession ? .reconnecting : .currentActivity
        }
        return .restTimer
    }

    func currentActivityPrimaryAction(isPaused: Bool) -> CurrentActivityPrimaryAction {
        isPaused ? .resumeActivity : .openCurrentActivity
    }

    func currentActivityControlsAction(isRecoveringRecentSession: Bool) -> CurrentActivityControlsAction {
        isRecoveringRecentSession ? .reconnectControls : .openControls
    }

    func currentActivityPrimaryActionTitle(isPaused: Bool) -> String {
        switch currentActivityPrimaryAction(isPaused: isPaused) {
        case .resumeActivity:
            return String(localized: "watch.activities.action.resume_activity", defaultValue: "Resume Activity")
        case .openCurrentActivity:
            return String(localized: "watch.activities.action.open_current_activity", defaultValue: "Open Current Activity")
        }
    }

    func currentActivityControlsActionTitle(isRecoveringRecentSession: Bool) -> String {
        switch currentActivityControlsAction(isRecoveringRecentSession: isRecoveringRecentSession) {
        case .reconnectControls:
            return String(localized: "watch.activities.action.reconnect_controls", defaultValue: "Reconnect Controls")
        case .openControls:
            return String(localized: "watch.activities.action.open_controls", defaultValue: "Open Controls")
        }
    }

    func trackedControlsPrimaryActionTitle(isPaused: Bool) -> String {
        switch trackedControlsPrimaryAction(isPaused: isPaused) {
        case .resume:
            return String(localized: "watch.now_playing.action.resume", defaultValue: "Resume")
        case .pause:
            return String(localized: "watch.now_playing.action.pause", defaultValue: "Pause")
        }
    }

    func footerText(isTrackedActivitySession: Bool, isRecoveringRecentSession: Bool) -> String {
        switch footerStyle(isTrackedActivitySession: isTrackedActivitySession, isRecoveringRecentSession: isRecoveringRecentSession) {
        case .reconnecting:
            return String(localized: "watch.now_playing.footer.recovery_hint", defaultValue: "Controls stay here while the watch reconnects to your iPhone session.")
        case .currentActivity:
            return String(localized: "watch.now_playing.footer.current_activity_hint", defaultValue: "Use these controls to keep the current activity honest from your watch.")
        case .restTimer:
            return String(localized: "watch.now_playing.rest", defaultValue: "Rest")
        }
    }
}
